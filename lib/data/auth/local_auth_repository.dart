// lib/data/auth/local_auth_repository.dart
//
// پیاده‌سازی محلی (SQLite) قرارداد [AuthRepository].
//
// نکات امنیتی:
// - رمز عبور هرگز به صورت متن ساده ذخیره نمی‌شود؛ فقط هش PBKDF2
//   (HMAC-SHA256، ۱۲۰٬۰۰۰ تکرار، ۲۵۶ بیت) به‌همراه نمک ۳۲ بایتی تصادفی.
// - نمک و هش هر دو به صورت base64 در جدول `accounts` نگه‌داری می‌شوند.
// - مقایسهٔ هش‌ها با حلقهٔ زمان‌ثابت انجام می‌شود تا از حملهٔ زمان‌سنجی
//   اطلاعات نشت نکند.
// - ایمیل‌ها با حروف کوچک ذخیره و جست‌وجو می‌شوند تا یکتایی
//   نسبت به بزرگی/کوچکی حروف رعایت شود.
//
// این فایل فقط به دیتابیس مشترک [DatabaseHelper.instance.database]
// دسترسی دارد و اسکیما را تغییر نمی‌دهد.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/domain/models/account.dart';
import 'package:english_teacher/domain/repositories/auth_repository.dart';

/// پیاده‌سازی محلی احراز هویت روی SQLite + SharedPreferences.
class LocalAuthRepository implements AuthRepository {
  /// کلید ذخیرهٔ شناسهٔ حساب فعال در SharedPreferences
  static const String activeAccountKey = 'active_account_id';

  // الگوریتم هش رمز: PBKDF2 با HMAC-SHA256، ۱۲۰٬۰۰۰ تکرار، خروجی ۲۵۶ بیت
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  // اعتبارسنجی سادهٔ قالب ایمیل
  static final RegExp _emailRegex =
      RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

  // جریان پخشی حساب فعال؛ هر تغییری در حساب فعال اینجا منتشر می‌شود
  final StreamController<Account?> _controller =
      StreamController<Account?>.broadcast();

  LocalAuthRepository() {
    // انتشار اولیهٔ وضعیت حساب فعال (بدون مسدودکردن سازنده)
    unawaited(_emitCurrent());
  }

  // ───────────────────────── Stream ─────────────────────────

  @override
  Stream<Account?> currentAccountStream() => _controller.stream;

  /// خواندن حساب فعال و انتشار آن در جریان
  Future<void> _emitCurrent() async {
    try {
      _controller.add(await currentAccount());
    } catch (_) {
      // اگر دیتابیس هنوز آماده نیست، null منتشر کن تا جریان زنده بماند
      _controller.add(null);
    }
  }

  // ───────────────────────── خواندن ─────────────────────────

  @override
  Future<Account?> currentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(activeAccountKey);
    if (activeId == null) return null;
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [activeId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Account.fromMap(rows.first);
  }

  @override
  Future<List<Account>> listAccounts() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'is_deleted = 0',
      // جدیدترین ورود اول؛ حساب‌هایی که هرگز وارد نشده‌اند آخر می‌آیند
      orderBy: 'last_login_at DESC',
    );
    return rows.map(Account.fromMap).toList();
  }

  /// یافتن حساب حذف‌نشده با ایمیل (مقایسهٔ بدون توجه به بزرگی/کوچکی حروف)
  Future<Map<String, Object?>?> _findByEmail(String email) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'lower(email) = ? AND is_deleted = 0',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  // ───────────────────────── ثبت‌نام / ورود ─────────────────────────

  @override
  Future<Account> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    // اعتبارسنجی ورودی‌ها با پیام‌های فارسی
    if (name.trim().isEmpty) {
      throw const AuthException('نام نمی‌تواند خالی باشد');
    }
    final normalizedEmail = email.trim().toLowerCase();
    if (!_emailRegex.hasMatch(normalizedEmail)) {
      throw const AuthException('ایمیل معتبر نیست');
    }
    if (password.length < 6) {
      throw const AuthException('رمز عبور باید حداقل ۶ کاراکتر باشد');
    }

    // یکتایی ایمیل (بدون توجه به بزرگی/کوچکی حروف)
    final existing = await _findByEmail(normalizedEmail);
    if (existing != null) {
      throw const AuthException('این ایمیل قبلاً ثبت شده است');
    }

    // ساخت نمک تصادفی و هش رمز — رمز ساده هرگز ذخیره نمی‌شود
    final salt = _randomSalt();
    final hash = await _hashPassword(password, salt);

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();

    final db = await DatabaseHelper.instance.database;
    await db.insert('accounts', {
      'id': id,
      'email': normalizedEmail,
      'name': name.trim(),
      'password_hash': base64Encode(hash),
      'salt': base64Encode(salt),
      'created_at': now,
      'last_login_at': now,
      'is_deleted': 0,
      'updated_at': now,
      'firebase_uid': null,
    });

    // حساب تازه‌ساخته‌شده فعال می‌شود
    await _setActive(id);

    final account = Account(
      id: id,
      email: normalizedEmail,
      name: name.trim(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      lastLoginAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    _controller.add(account);
    return account;
  }

  @override
  Future<Account> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final row = await _findByEmail(normalizedEmail);
    if (row == null) {
      // عمداً پیام یکسان برای ایمیل ناموجود و رمز اشتباه (جلوگیری از شمارش حساب‌ها)
      throw const AuthException('ایمیل یا رمز عبور اشتباه است');
    }

    final salt = base64Decode(row['salt'] as String);
    final expected = base64Decode(row['password_hash'] as String);
    final actual = await _hashPassword(password, salt);

    if (!_constantTimeEquals(expected, actual)) {
      throw const AuthException('ایمیل یا رمز عبور اشتباه است');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'accounts',
      {'last_login_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [row['id'] as String],
    );

    await _setActive(row['id'] as String);
    final account = Account.fromMap({
      ...row,
      'last_login_at': now,
      'updated_at': now,
    });
    _controller.add(account);
    return account;
  }

  // ───────────────────────── جابه‌جایی / خروج / حذف ─────────────────────────

  @override
  Future<Account> switchAccount(String accountId) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'accounts',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const AuthException('حساب یافت نشد');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'accounts',
      {'last_login_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [accountId],
    );
    await _setActive(accountId);
    final account = Account.fromMap({
      ...rows.first,
      'last_login_at': now,
      'updated_at': now,
    });
    _controller.add(account);
    return account;
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(activeAccountKey);
    _controller.add(null);
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    final db = await DatabaseHelper.instance.database;

    // پاک‌سازی دستی داده‌های وابسته به این حساب (جداول مرحله‌های ۲ تا ۶)
    const dependentTables = [
      'chat_messages',
      'scores',
      'exercises',
      'flashcards',
      'words',
      'grammar_rules',
      'homeworks',
    ];
    await db.transaction((txn) async {
      for (final table in dependentTables) {
        await txn.delete(
          table,
          where: 'account_id = ?',
          whereArgs: [accountId],
        );
      }
      // حذف نرم خود حساب
      await txn.update(
        'accounts',
        {
          'is_deleted': 1,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [accountId],
      );
    });

    // اگر حساب حذف‌شده همان حساب فعال بود، حساب دیگری را فعال کن یا خالی بمان
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(activeAccountKey) == accountId) {
      final remaining = await listAccounts();
      if (remaining.isNotEmpty) {
        await _setActive(remaining.first.id);
        _controller.add(remaining.first);
      } else {
        await prefs.remove(activeAccountKey);
        _controller.add(null);
      }
    }
  }

  // ───────────────────────── بازیابی رمز ─────────────────────────

  @override
  Future<void> requestPasswordReset(String email) async {
    // TODO (مرحلهٔ ۷ — همگام‌سازی ابری):
    // ارسال ایمیل بازیابی نیازمند سرویس ایمیل/بک‌اند است که هنوز وجود ندارد.
    // در مرحلهٔ ۷ با Firebase Auth این متد واقعی می‌شود.
    throw const AuthException(
      'بازیابی رمز با ایمیل در مرحله ۷ (همگام‌سازی ابری) فعال می‌شود',
    );
  }

  // ───────────────────────── ابزارهای داخلی ─────────────────────────

  /// ذخیرهٔ شناسهٔ حساب فعال در SharedPreferences
  Future<void> _setActive(String accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(activeAccountKey, accountId);
  }

  /// تولید نمک ۳۲ بایتی با مولد تصادفی امن
  List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }

  /// هش PBKDF2 رمز با نمک داده‌شده؛ خروجی ۳۲ بایت (۲۵۶ بیت)
  Future<List<int>> _hashPassword(String password, List<int> salt) async {
    final secretKey = await _pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  /// مقایسهٔ زمان‌ثابت دو دنباله بایت؛
  /// زمان اجرا به محتوای ورودی بستگی ندارد.
  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// بستن جریان (در صورت نیاز هنگام نابودی)
  Future<void> dispose() => _controller.close();
}
