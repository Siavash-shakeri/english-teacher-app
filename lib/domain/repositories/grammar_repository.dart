// lib/domain/repositories/grammar_repository.dart
//
// قرارداد مخزن «قواعد من» (مرحلهٔ ۴ — قواعد).
// همهٔ عملیات در محدودهٔ حساب فعال انجام می‌شوند؛ حذف، نرم است.
//
// قانون عدم تکرار: قاعده‌ای که قبلاً با همان دسته و عنوان (بدون حساسیت
// به بزرگی/کوچکی حروف و فاصله‌های اضافی) ثبت شده، دوباره ساخته نمی‌شود؛
// فقط محتوایش به‌روز می‌شود و همان رکورد برمی‌گردد.

import 'package:english_teacher/domain/models/grammar_rule.dart';

/// قرارداد دسترسی به قواعد گرامری دفتر «قواعد من».
abstract class GrammarRepository {
  /// فهرست همهٔ قواعد زندهٔ حساب فعال، مرتب بر اساس دسته و سپس عنوان.
  /// با [category] فقط قواعد همان دسته برمی‌گردند.
  Future<List<GrammarRule>> listRules({String? category});

  /// فهرست دسته‌های موجود برای حساب فعال (مرتب الفبایی).
  Future<List<String>> listCategories();

  /// جست‌وجو در عنوان، دسته و توضیح قواعد زندهٔ حساب فعال.
  Future<List<GrammarRule>> searchRules(String query);

  /// خواندن یک قاعده با شناسه؛ در صورت نبود، null برمی‌گردد.
  Future<GrammarRule?> getRule(String id);

  /// درج یا به‌روزرسانی قاعده.
  ///
  /// اگر قاعده‌ای با همان دسته+عنوان (نرمال‌شده) برای حساب فعال
  /// وجود داشته باشد، فقط فیلدهای آن به‌روز می‌شود (first_seen_at
  /// اولیه حفظ می‌شود) و همان رکورد برمی‌گردد؛ در غیر این صورت
  /// رکورد جدیدی با UUID ساخته می‌شود.
  Future<GrammarRule> upsertRule({
    required String category,
    required String title,
    required String explanation,
    String? formula,
    List<String>? examples,
    List<String>? commonMistakes,
  });

  /// ستاره‌دار کردن یا برداشتن ستاره از یک قاعده.
  Future<void> setStarred(String id, bool starred);

  /// حذف نرم قاعده (`is_deleted = 1`)؛ فقط در محدودهٔ حساب فعال.
  Future<void> deleteRule(String id);
}
