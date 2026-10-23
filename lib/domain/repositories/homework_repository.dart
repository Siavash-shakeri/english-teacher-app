// lib/domain/repositories/homework_repository.dart
//
// قرارداد لایهٔ دامنه برای مدیریت تکالیف دست‌نویس اسکن‌شده (مرحلهٔ ۲).
// همهٔ عملیات روی تکالیفِ «حساب فعال» انجام می‌شود؛ اگر حساب فعالی
// وجود نداشته باشد، پیاده‌سازی باید [StateError] پرتاب کند.

import 'package:english_teacher/domain/models/homework.dart';

/// قرارداد مخزن تکالیف.
///
/// پیاده‌سازی‌ها (محلی SQLite در مرحلهٔ ۲، ابری در مرحلهٔ ۷)
/// باید همین رابط را رعایت کنند تا لایهٔ ارائه بی‌تغییر بماند.
abstract class HomeworkRepository {
  /// تکالیفِ حساب فعالِ حذف‌نشده، به ترتیب جدیدترین اول.
  Future<List<Homework>> listHomeworks();

  /// ساخت تکلیف تازه برای حساب فعال.
  ///
  /// اگر `title` خالی باشد، عنوان «بدون عنوان» ثبت می‌شود.
  /// `imagePaths` می‌تواند خالی باشد (تکلیفِ بدون تصویر).
  Future<Homework> createHomework({
    required String title,
    required List<String> imagePaths,
    required String extractedText,
  });

  /// حذف نرم تکلیف (`is_deleted = 1`).
  ///
  /// فقط تکلیفی که متعلق به حساب فعال باشد حذف می‌شود.
  Future<void> deleteHomework(String id);
}
