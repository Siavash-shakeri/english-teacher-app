// lib/data/review/spaced_repetition.dart
//
// زمان‌بند «تکرار با فاصله» (مرحلهٔ ۶) — نسخهٔ سبک SM-2.
//
// روی هر دو جدول `words` و `flashcards` کار می‌کند؛ هر دو ستون‌های
// next_review_at، interval_days، ease و repetitions را دارند.
// همهٔ عملیات در محدودهٔ حساب فعال انجام می‌شود.

import 'package:shared_preferences/shared_preferences.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';

/// یک آیتم قابل مرور (کلمه یا فلش‌کارت).
class ReviewItem {
  /// شناسهٔ ردیف در جدول خودش
  final String id;

  /// نام جدول: 'words' یا 'flashcards'
  final String table;

  /// روی کارت (کلمهٔ انگلیسی یا روی فلش‌کارت)
  final String front;

  /// پشت کارت (معنی فارسی یا پشت فلش‌کارت)
  final String back;

  /// عنوان نمایشی جدول برای رابط کاربری
  String get tableFaName => table == 'words' ? 'واژگان' : 'فلش‌کارت';

  const ReviewItem({
    required this.id,
    required this.table,
    required this.front,
    required this.back,
  });
}

/// زمان‌بند تکرار با فاصله — الگوریتم SM-2 ساده‌شده.
///
/// - پاسخ درست: repetitions ‏+۱؛ فاصله ۱، ۶، بعد interval×ease؛
///   ease ‏+۰٫۱ (سقف ۳).
/// - پاسخ غلط: repetitions صفر، فاصله ۱ روز، ease ‏−۰٫۸ (کف ۱٫۳).
class SpacedRepetition {
  static const _tables = ['words', 'flashcards'];

  Future<String> _activeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(LocalAuthRepository.activeAccountKey);
    if (id == null || id.isEmpty) {
      throw StateError('no active account');
    }
    return id;
  }

  /// آیتم‌های سررسیده (next_review_at تهی یا گذشته)، قدیمی‌ترین اول.
  Future<List<ReviewItem>> dueReviews({int limit = 50}) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final items = <ReviewItem>[];
    for (final table in _tables) {
      final rows = await db.query(
        table,
        where: 'account_id = ? AND is_deleted = 0 '
            'AND (next_review_at IS NULL OR next_review_at <= ?)',
        whereArgs: [accountId, now],
        orderBy: 'next_review_at ASC',
        limit: limit,
      );
      for (final r in rows) {
        items.add(ReviewItem(
          id: r['id'] as String,
          table: table,
          front: (table == 'words'
                  ? r['word']
                  : r['front']) as String? ??
              '',
          back: (table == 'words'
                  ? r['meaning']
                  : r['back']) as String? ??
              '',
        ));
        if (items.length >= limit) break;
      }
      if (items.length >= limit) break;
    }
    return items;
  }

  /// تعداد آیتم‌های سررسیده.
  Future<int> dueCount() async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    var total = 0;
    for (final table in _tables) {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $table WHERE account_id = ? '
        'AND is_deleted = 0 AND (next_review_at IS NULL OR next_review_at <= ?)',
        [accountId, now],
      );
      total += (rows.first['c'] as num?)?.toInt() ?? 0;
    }
    return total;
  }

  /// ثبت نتیجهٔ یک مرور و به‌روزرسانی زمان‌بندی SM-2.
  Future<void> review({
    required String table,
    required String id,
    required bool correct,
  }) async {
    if (!_tables.contains(table)) {
      throw ArgumentError('unknown review table: $table');
    }
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      table,
      where: 'id = ? AND account_id = ? AND is_deleted = 0',
      whereArgs: [id, accountId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final row = rows.first;

    var repetitions = (row['repetitions'] as num?)?.toInt() ?? 0;
    var interval = (row['interval_days'] as num?)?.toInt() ?? 1;
    var ease = (row['ease'] as num?)?.toDouble() ?? 2.5;

    if (correct) {
      repetitions += 1;
      ease = (ease + 0.1).clamp(1.3, 3.0);
      if (repetitions == 1) {
        interval = 1;
      } else if (repetitions == 2) {
        interval = 6;
      } else {
        interval = (interval * ease).round().clamp(1, 3650);
      }
    } else {
      repetitions = 0;
      ease = (ease - 0.8).clamp(1.3, 3.0);
      interval = 1;
    }

    final next = DateTime.now().add(Duration(days: interval));
    await db.update(
      table,
      {
        'repetitions': repetitions,
        'interval_days': interval,
        'ease': ease,
        'next_review_at': next.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND account_id = ?',
      whereArgs: [id, accountId],
    );
  }
}
