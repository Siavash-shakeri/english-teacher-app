// lib/domain/models/word.dart
//
// مدل دامنهٔ «کلمهٔ واژگان» (مرحلهٔ ۳ — ترجمه).
// هر کلمه متعلق به یک حساب کاربری است و داده‌های لازم برای
// مرور با فاصلهٔ زمانی (Spaced Repetition) را نگه می‌دارد.

/// نمایندهٔ یک کلمهٔ ذخیره‌شده در دفتر واژگان.
///
/// ردیف جدول `words` را می‌خواند؛ زمان‌ها epoch-milliseconds هستند
/// و حذف، نرم (`is_deleted`) انجام می‌شود.
///
/// نکتهٔ صداقت: `pronunciation` و `pos` فعلاً تهی‌اند و در مرحلهٔ ۵
/// (معلم هوش مصنوعی) پر می‌شوند؛ هرگز مقدار ساختگی در آن‌ها
/// قرار نمی‌گیرد.
class Word {
  /// شناسهٔ یکتای کلمه (UUID نسخهٔ ۴)
  final String id;

  /// شناسهٔ حسابی که این کلمه به آن تعلق دارد
  final String accountId;

  /// خود کلمهٔ انگلیسی (به همان صورتی که کاربر ثبت کرده، با فاصله‌های اضافی پاک‌شده)
  final String word;

  /// معنی فارسی کلمه
  final String meaning;

  /// تلفظ (مثلاً آوانگاری)؛ فعلاً تهی، در مرحلهٔ ۵ پر می‌شود
  final String? pronunciation;

  /// نقش دستوری (اسم، فعل، ...)؛ فعلاً تهی، در مرحلهٔ ۵ پر می‌شود
  final String? pos;

  /// جملهٔ نمونه
  final String? example;

  /// منشأ ثبت کلمه (مثلاً شناسهٔ تکلیف یا «دستی»)
  final String? source;

  /// زمان بعدی مرور با فاصلهٔ زمانی؛ تهی یعنی هنوز برنامه‌ریزی نشده
  final DateTime? nextReviewAt;

  /// فاصلهٔ فعلی مرور به روز
  final int intervalDays;

  /// ضریب سهولت (الگوریتم SM-2)؛ مقدار آغازین ۲٫۵
  final double ease;

  /// تعداد مرورهای موفق پیاپی
  final int repetitions;

  /// زمان ساخت رکورد
  final DateTime createdAt;

  /// زمان آخرین به‌روزرسانی رکورد
  final DateTime updatedAt;

  const Word({
    required this.id,
    required this.accountId,
    required this.word,
    required this.meaning,
    this.pronunciation,
    this.pos,
    this.example,
    this.source,
    this.nextReviewAt,
    this.intervalDays = 1,
    this.ease = 2.5,
    this.repetitions = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// ساخت از یک ردیف جدول `words`.
  ///
  /// ستون‌ها: id، account_id، word، meaning، pronunciation، pos، example،
  /// source، next_review_at (epoch-ms و قابل تهی)، interval_days، ease،
  /// repetitions، created_at، updated_at، is_deleted.
  factory Word.fromMap(Map<String, Object?> map) {
    final nextReviewMs = (map['next_review_at'] as num?)?.toInt();
    return Word(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      word: map['word'] as String? ?? '',
      meaning: map['meaning'] as String? ?? '',
      pronunciation: map['pronunciation'] as String?,
      pos: map['pos'] as String?,
      example: map['example'] as String?,
      source: map['source'] as String?,
      nextReviewAt: nextReviewMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(nextReviewMs),
      intervalDays: (map['interval_days'] as num?)?.toInt() ?? 1,
      ease: (map['ease'] as num?)?.toDouble() ?? 2.5,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((map['created_at'] as num?)?.toInt() ?? 0),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((map['updated_at'] as num?)?.toInt() ?? 0),
    );
  }

  /// تبدیل به ردیف قابل درج در جدول `words`.
  ///
  /// `is_deleted` همیشه ۰ (زنده) نوشته می‌شود؛ حذف نرم از طریق مخزن
  /// انجام می‌گیرد. `next_review_at` به صورت epoch-ms و در صورت تهی،
  /// تهی نوشته می‌شود.
  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'word': word,
        'meaning': meaning,
        'pronunciation': pronunciation,
        'pos': pos,
        'example': example,
        'source': source,
        'next_review_at': nextReviewAt?.millisecondsSinceEpoch,
        'interval_days': intervalDays,
        'ease': ease,
        'repetitions': repetitions,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'is_deleted': 0,
      };

  @override
  String toString() => 'Word(id: $id, word: $word, meaning: $meaning)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Word && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
