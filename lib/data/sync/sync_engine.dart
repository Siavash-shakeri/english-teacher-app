// lib/data/sync/sync_engine.dart
//
// موتور همگام‌سازی ابری مرحلهٔ ۷.
//
// قانون حل تعارض (مطابق خواستهٔ کاربر):
//   «جدیدترین می‌ماند، نسخهٔ قبلی نگه‌داری می‌شود»
// هر وقت نسخه‌ای بازنویسی شود، هر دو نسخه (برنده و بازنده) با
// زمان‌شان در فایل محلی sync_conflicts.jsonl ثبت می‌شوند.
//
// دیتابیس محلی (SQLite) همیشه مرجع اصلی است؛ همگام‌سازی افزودنی است
// و هیچ‌وقت دادهٔ محلی را بدون ثبت در لاگ تعارض پاک نمی‌کند.
// اگر Firebase پیکربندی نشده باشد، همهٔ فراخوانی‌ها خطای فارسی
// می‌دهند و اپ کاملاً آفلاین کار می‌کند.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/data/sync/firebase_service.dart';

/// نتیجهٔ یک عملیات همگام‌سازی.
class SyncResult {
  final bool ok;
  final String message;
  final int pushed;
  final int pulled;
  final int conflicts;

  const SyncResult({
    required this.ok,
    required this.message,
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = 0,
  });
}

/// موتور همگام‌سازی جداول محلی با Cloud Firestore.
class SyncEngine {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  static const String _lastSyncKey = 'last_sync_at';
  static const String _autoSyncKey = 'auto_sync';

  /// جدول‌ها + ستون نسخه برای مقایسهٔ «جدیدترین».
  /// (scores ستون updated_at ندارد؛ از taken_at استفاده می‌شود.)
  static const Map<String, String> _tables = {
    'homeworks': 'updated_at',
    'grammar_rules': 'updated_at',
    'words': 'updated_at',
    'flashcards': 'updated_at',
    'exercises': 'updated_at',
    'scores': 'taken_at',
    'chat_messages': 'updated_at',
  };

  /// ستون‌های REAL که ممکن است از Firestore به‌صورت int برگردند.
  static const Map<String, List<String>> _realColumns = {
    'words': ['ease'],
    'flashcards': ['ease'],
    'scores': ['score', 'total'],
  };

  final FirebaseService _fb = FirebaseService.instance;

  // ───────────────────────── تنظیمات ─────────────────────────

  /// آخرین زمان همگام‌سازی موفق (epoch-ms)؛ null یعنی هرگز.
  Future<int?> get lastSyncAt async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncKey);
  }

  Future<bool> get autoSyncEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncKey) ?? true;
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncKey, value);
  }

  Future<bool> get isOnline async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  // ───────────────────────── پشتیبان‌گیری ─────────────────────────

  /// آپلود همهٔ داده‌های حساب فعال به ابر.
  Future<SyncResult> backupNow({
    void Function(double progress)? onProgress,
  }) async {
    _requireReady();
    final uid = await _ensureUid();
    final db = await DatabaseHelper.instance.database;
    final accountId = await _activeAccountId();
    final fs = _fb.firestore;

    int pushed = 0;
    final tables = _tables.keys.toList();
    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      final rows = await db.query(table,
          where: 'account_id = ?', whereArgs: [accountId]);
      for (final row in rows) {
        final doc = _toCloudDoc(table, row);
        await fs
            .collection('users')
            .doc(uid)
            .collection(table)
            .doc(row['id'] as String)
            .set(doc, SetOptions(merge: true));
        pushed++;
      }
      onProgress?.call((i + 1) / tables.length * 0.8);
    }

    // نگاشت firebase_uid روی حساب محلی
    await db.update(
      'accounts',
      {'firebase_uid': uid, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    onProgress?.call(0.9);

    await _setLastSyncAt(_now());
    onProgress?.call(1.0);
    return SyncResult(
      ok: true,
      message: 'پشتیبان‌گیری کامل شد؛ $pushed رکورد آپلود شد.',
      pushed: pushed,
    );
  }

  // ───────────────────────── بازیابی ─────────────────────────

  /// دانلود از ابر و ادغام با دادهٔ محلی (قانون جدیدترین‌می‌ماند).
  Future<SyncResult> restoreFromCloud({
    void Function(double progress)? onProgress,
  }) async {
    _requireReady();
    final uid = _fb.uid;
    if (uid == null) {
      throw const FirebaseNotConfiguredException(
          'برای بازیابی ابتدا باید وارد حساب Firebase شوید.');
    }
    final db = await DatabaseHelper.instance.database;
    final accountId = await _activeAccountId();
    final fs = _fb.firestore;

    int pulled = 0;
    int conflicts = 0;
    final tables = _tables.keys.toList();
    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      final versionCol = _tables[table]!;
      final snap = await fs
          .collection('users')
          .doc(uid)
          .collection(table)
          .get();
      for (final doc in snap.docs) {
        final cloud = _fromCloudDoc(table, doc.data(), accountId);
        final localRows = await db.query(table,
            where: 'id = ? AND account_id = ?',
            whereArgs: [doc.id, accountId]);
        if (localRows.isEmpty) {
          await db.insert(table, cloud);
          pulled++;
        } else {
          final local = localRows.first;
          final localVer = _versionOf(local, versionCol);
          final cloudVer = _versionOf(cloud, versionCol);
          if (cloudVer > localVer) {
            await _logConflict(
              table: table,
              id: doc.id,
              winner: 'cloud',
              local: local,
              cloud: cloud,
            );
            await db.update(table, cloud,
                where: 'id = ? AND account_id = ?',
                whereArgs: [doc.id, accountId]);
            pulled++;
            conflicts++;
          } else if (localVer > cloudVer) {
            // محلی جدیدتر است؛ در پشتیبان بعدی آپلود می‌شود.
            // نسخهٔ ابریِ قدیمی را هم در لاگ نگه می‌داریم.
            await _logConflict(
              table: table,
              id: doc.id,
              winner: 'local',
              local: local,
              cloud: cloud,
            );
            conflicts++;
          }
        }
      }
      onProgress?.call((i + 1) / tables.length);
    }

    await _setLastSyncAt(_now());
    return SyncResult(
      ok: true,
      message: conflicts == 0
          ? 'بازیابی کامل شد؛ $pulled رکورد به‌روز شد.'
          : 'بازیابی کامل شد؛ $pulled رکورد، $conflicts تعارض (جدیدترین ماند).',
      pulled: pulled,
      conflicts: conflicts,
    );
  }

  // ───────────────────────── خودکار ─────────────────────────

  /// اگر همگام‌سازی خودکار فعال و آنلاین باشیم، پشتیبان می‌گیرد.
  /// هرگز خطا پرتاب نمی‌کند (برای فراخوانی از شنوندهٔ اتصال).
  Future<bool> autoSyncIfNeeded() async {
    try {
      if (!await autoSyncEnabled) return false;
      if (!_fb.isConfigured || _fb.uid == null) return false;
      if (!await isOnline) return false;
      final r = await backupNow();
      return r.ok;
    } catch (_) {
      return false;
    }
  }

  /// آیا در ابر برای این کاربر داده‌ای هست؟
  Future<bool> cloudHasData() async {
    if (!_fb.isConfigured || _fb.uid == null) return false;
    final fs = _fb.firestore;
    final uid = _fb.uid!;
    for (final table in _tables.keys) {
      final snap = await fs
          .collection('users')
          .doc(uid)
          .collection(table)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return true;
    }
    return false;
  }

  /// آیا جدول‌های محلی حساب فعال خالی‌اند؟
  Future<bool> localIsEmpty() async {
    final db = await DatabaseHelper.instance.database;
    final accountId = await _activeAccountId();
    for (final table in _tables.keys) {
      // جدول scores ستون is_deleted ندارد
      final where = table == 'scores'
          ? 'account_id = ?'
          : 'account_id = ? AND is_deleted = 0';
      final rows = await db.query(
        table,
        columns: ['id'],
        where: where,
        whereArgs: [accountId],
        limit: 1,
      );
      if (rows.isNotEmpty) return false;
    }
    return true;
  }

  // ───────────────────────── ابزارهای داخلی ─────────────────────────

  void _requireReady() {
    if (!_fb.isConfigured) {
      throw const FirebaseNotConfiguredException();
    }
  }

  Future<String> _ensureUid() async {
    final existing = _fb.uid;
    if (existing != null) return existing;
    final db = await DatabaseHelper.instance.database;
    final accountId = await _activeAccountId();
    final rows = await db.query('accounts',
        columns: ['email'], where: 'id = ?', whereArgs: [accountId]);
    final email = rows.isNotEmpty ? rows.first['email'] as String : '';
    if (email.isEmpty) {
      throw const FirebaseNotConfiguredException(
          'ایمیل حساب فعال یافت نشد.');
    }
    return _fb.ensureFirebaseUser(email);
  }

  Future<String> _activeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(LocalAuthRepository.activeAccountKey);
    if (id == null || id.isEmpty) {
      throw const FirebaseNotConfiguredException(
          'حساب فعالی انتخاب نشده است.');
    }
    return id;
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> _setLastSyncAt(int ms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, ms);
  }

  /// تبدیل ردیف SQLite به سند Firestore (فقط مقادیر ساده).
  Map<String, Object?> _toCloudDoc(
      String table, Map<String, Object?> row) {
    final doc = Map<String, Object?>.from(row);
    doc.remove('account_id'); // در مسیر سند مشخص است
    return doc;
  }

  /// تبدیل سند Firestore به ردیف SQLite (با account_id و اصلاح نوع REAL).
  Map<String, Object?> _fromCloudDoc(
    String table,
    Map<String, Object?> data,
    String accountId,
  ) {
    final row = Map<String, Object?>.from(data);
    row['account_id'] = accountId;
    final reals = _realColumns[table];
    if (reals != null) {
      for (final col in reals) {
        final v = row[col];
        if (v is int) row[col] = v.toDouble();
      }
    }
    if (!row.containsKey('is_deleted')) row['is_deleted'] = 0;
    return row;
  }

  int _versionOf(Map<String, Object?> row, String versionCol) {
    final v = row[versionCol];
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  /// ثبت تعارض در فایل محلی (نسخهٔ بازنده نگه‌داری می‌شود).
  Future<void> _logConflict({
    required String table,
    required String id,
    required String winner, // 'local' | 'cloud'
    required Map<String, Object?> local,
    required Map<String, Object?> cloud,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/sync_conflicts.jsonl');
      final entry = jsonEncode({
        'at': _now(),
        'table': table,
        'id': id,
        'winner': winner,
        'local_updated': _versionOf(local, _tables[table]!),
        'cloud_updated': _versionOf(cloud, _tables[table]!),
        'loser_snapshot': winner == 'local' ? cloud : local,
      });
      await file.writeAsString('$entry\n', mode: FileMode.append);
    } catch (_) {
      // لاگ تعارض نباید خودِ همگام‌سازی را بشکند
    }
  }
}
