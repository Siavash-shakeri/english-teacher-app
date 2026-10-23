// lib/domain/repositories/vocabulary_repository.dart
//
// قرارداد مخزن «دفتر واژگان» (مرحلهٔ ۳ — ترجمه).
// همهٔ عملیات در محدودهٔ حساب فعال انجام می‌شوند؛ حذف، نرم است.

import 'package:english_teacher/domain/models/word.dart';

/// قرارداد دسترسی به کلمات دفتر واژگان.
abstract class VocabularyRepository {
  /// فهرست کلمات حساب فعال (فقط زنده‌ها: `is_deleted = 0`)،
  /// از جدیدترین به قدیمی‌ترین بر اساس `created_at`.
  Future<List<Word>> listWords();

  /// درج یا به‌روزرسانی کلمه.
  ///
  /// اگر همین کلمه (بدون حساسیت به بزرگی/کوچکی حروف) برای حساب فعال
  /// قبلاً ثبت شده و حذف نشده باشد، فقط `meaning`، `example`، `source`
  /// و `updated_at` آن به‌روز می‌شود و همان رکورد برمی‌گردد؛
  /// در غیر این صورت رکورد جدیدی با UUID ساخته می‌شود
  /// (`intervalDays` آغازین ۱، `ease` برابر ۲٫۵، `repetitions` برابر ۰
  /// و `nextReviewAt` برابر اکنون).
  Future<Word> upsertWord({
    required String word,
    required String meaning,
    String? example,
    String? source,
  });

  /// حذف نرم کلمه (`is_deleted = 1`)؛ فقط در محدودهٔ حساب فعال.
  Future<void> deleteWord(String id);
}
