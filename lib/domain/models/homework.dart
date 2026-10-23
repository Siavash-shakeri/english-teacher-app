// lib/domain/models/homework.dart
//
// مدل دامنهٔ «تکلیف دست‌نویس» (مرحلهٔ ۲ — اسکن).
// یک تکلیف مجموعه‌ای از صفحه‌های تصویرِ اسکن‌شده به‌همراه متن
// استخراج‌شده از OCR است و همیشه متعلق به یک حساب کاربری است.

import 'dart:convert';

/// نمایندهٔ یک تکلیف در لایهٔ دامنه.
///
/// ردیف جدول `homeworks` را می‌خواند؛ مسیرهای تصاویر به صورت
/// آرایهٔ JSON در ستون `image_paths` ذخیره شده‌اند و اینجا
/// به [List] از رشته تبدیل می‌شوند. زمان‌ها epoch-milliseconds هستند.
class Homework {
  /// شناسهٔ یکتای تکلیف (UUID نسخهٔ ۴)
  final String id;

  /// شناسهٔ حسابی که این تکلیف به آن تعلق دارد
  final String accountId;

  /// عنوان تکلیف (نمایشی در فهرست)
  final String title;

  /// زمان ساخت تکلیف
  final DateTime createdAt;

  /// زمان آخرین به‌روزرسانی تکلیف
  final DateTime updatedAt;

  /// مسیر فایل‌های تصویر صفحه‌های تکلیف (به ترتیب افزودن)
  final List<String> imagePaths;

  /// متن استخراج‌شده از تصاویر (قابل ویرایش توسط کاربر)
  final String extractedText;

  const Homework({
    required this.id,
    required this.accountId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.imagePaths,
    required this.extractedText,
  });

  /// ساخت از یک ردیف جدول `homeworks`.
  ///
  /// اگر `image_paths` معتبر یا از نوع آرایه نباشد، فهرست خالی
  /// در نظر گرفته می‌شود تا خطا باعث از دست رفتن تکلیف نشود.
  factory Homework.fromMap(Map<String, Object?> map) {
    final rawPaths = map['image_paths'] as String?;
    List<String> paths = [];
    if (rawPaths != null && rawPaths.isNotEmpty) {
      final decoded = jsonDecode(rawPaths);
      if (decoded is List) paths = decoded.whereType<String>().toList();
    }
    return Homework(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      title: map['title'] as String? ?? '',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((map['created_at'] as num?)?.toInt() ?? 0),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((map['updated_at'] as num?)?.toInt() ?? 0),
      imagePaths: paths,
      extractedText: map['extracted_text'] as String? ?? '',
    );
  }

  /// تبدیل به ردیف قابل درج در جدول `homeworks`.
  ///
  /// `image_paths` به صورت JSON کد می‌شود و `is_deleted` همیشه ۰
  /// (زنده) نوشته می‌شود؛ حذف نرم از طریق مخزن انجام می‌گیرد.
  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'title': title,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'image_paths': jsonEncode(imagePaths),
        'extracted_text': extractedText,
        'is_deleted': 0,
      };

  @override
  String toString() =>
      'Homework(id: $id, title: $title, pages: ${imagePaths.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Homework &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
