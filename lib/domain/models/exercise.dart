// lib/domain/models/exercise.dart
//
// مدل دامنهٔ «مجموعهٔ تمرین» (مرحلهٔ ۶ — تمرین‌ها).
// یک مجموعه، یک آزمونِ تولیدشده از داده‌های خودِ کاربر است:
// مشق‌ها، واژگان و قواعد. سؤال‌ها به صورت JSON در ستون `payload`
// ذخیره می‌شوند چون ساختار هر نوع سؤال متفاوت است.

import 'dart:convert';

/// انواع سؤال‌های پشتیبانی‌شده.
class ExerciseType {
  static const String fillBlank = 'fill_blank';
  static const String multipleChoice = 'multiple_choice';
  static const String wordOrder = 'word_order';
  static const String translation = 'translation';

  /// نام فارسی هر نوع برای نمایش در رابط کاربری.
  static String faName(String type) {
    switch (type) {
      case fillBlank:
        return 'جای خالی';
      case multipleChoice:
        return 'تستی (انگلیسی → فارسی)';
      case wordOrder:
        return 'مرتب‌سازی کلمات';
      case translation:
        return 'تستی (فارسی → انگلیسی)';
      default:
        return type;
    }
  }

  static const List<String> all = [
    fillBlank,
    multipleChoice,
    wordOrder,
    translation,
  ];
}

/// یک سؤالِ تولیدشده (فقط در حافظه؛ در دیتابیس داخل `payload` ذخیره می‌شود).
class QuizQuestion {
  /// یکی از مقادیر [ExerciseType].
  final String type;

  /// متن سؤال (مثلاً جمله با جای خالی، یا «معنی X چیست؟»).
  final String prompt;

  /// گزینه‌ها (برای word_order: توکن‌های به‌هم‌ریخته).
  final List<String> options;

  /// پاسخ درست.
  final String answer;

  /// راهنمای اختیاری (مثلاً معنی کلمه).
  final String? hint;

  const QuizQuestion({
    required this.type,
    required this.prompt,
    required this.options,
    required this.answer,
    this.hint,
  });

  factory QuizQuestion.fromJson(Map<String, Object?> json) {
    return QuizQuestion(
      type: json['type'] as String? ?? ExerciseType.multipleChoice,
      prompt: json['prompt'] as String? ?? '',
      options: (json['options'] as List?)?.whereType<String>().toList() ?? [],
      answer: json['answer'] as String? ?? '',
      hint: json['hint'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'type': type,
        'prompt': prompt,
        'options': options,
        'answer': answer,
        if (hint != null) 'hint': hint,
      };
}

/// نمایندهٔ یک مجموعهٔ تمرین در لایهٔ دامنه.
///
/// ردیف جدول `exercises` را می‌خواند. چون جدول ستون عنوان ندارد،
/// عنوان نمایشی داخل `payload` (کلید `title`) نگه‌داری می‌شود.
/// سؤال‌ها هم در `payload` با کلید `questions` ذخیره می‌شوند.
class ExerciseSet {
  /// شناسهٔ یکتا (UUID نسخهٔ ۴)
  final String id;

  /// شناسهٔ حسابی که این مجموعه به آن تعلق دارد
  final String accountId;

  /// نوع غالب مجموعه (برای فیلتر نمایشی)؛ مجموعه‌ها می‌توانند ترکیبی باشند
  final String type;

  /// عنوان نمایشی مجموعه
  final String title;

  /// سؤال‌های مجموعه
  final List<QuizQuestion> questions;

  /// زمان ساخت
  final DateTime createdAt;

  /// زمان آخرین به‌روزرسانی
  final DateTime updatedAt;

  const ExerciseSet({
    required this.id,
    required this.accountId,
    required this.type,
    required this.title,
    required this.questions,
    required this.createdAt,
    required this.updatedAt,
  });

  /// ساخت از یک ردیف جدول `exercises`.
  factory ExerciseSet.fromMap(Map<String, Object?> map) {
    Map<String, Object?> payload = {};
    final raw = map['payload'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          payload = decoded.cast<String, Object?>();
        }
      } catch (_) {
        // payload خراب: مجموعه با سؤال خالی برگردانده می‌شود
      }
    }
    final rawQuestions = payload['questions'];
    final questions = <QuizQuestion>[];
    if (rawQuestions is List) {
      for (final q in rawQuestions) {
        if (q is Map) {
          questions.add(QuizQuestion.fromJson(q.cast<String, Object?>()));
        }
      }
    }
    return ExerciseSet(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      type: map['type'] as String? ?? ExerciseType.multipleChoice,
      title: payload['title'] as String? ?? 'تمرین',
      questions: questions,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num?)?.toInt() ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as num?)?.toInt() ?? 0),
    );
  }

  /// تبدیل به ردیف قابل درج در جدول `exercises`.
  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'type': type,
        'payload': jsonEncode({
          'title': title,
          'questions': questions.map((q) => q.toJson()).toList(),
        }),
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'is_deleted': 0,
      };

  @override
  String toString() =>
      'ExerciseSet(id: $id, title: $title, questions: ${questions.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseSet &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// یک رکورد نمرهٔ ثبت‌شده (جدول `scores`).
class ScoreRecord {
  final String id;
  final String accountId;
  final String? exerciseId;
  final double score;
  final double total;
  final DateTime takenAt;

  const ScoreRecord({
    required this.id,
    required this.accountId,
    this.exerciseId,
    required this.score,
    required this.total,
    required this.takenAt,
  });

  /// درصد نمره (۰ تا ۱۰۰).
  double get percent => total <= 0 ? 0 : (score / total * 100);

  factory ScoreRecord.fromMap(Map<String, Object?> map) {
    return ScoreRecord(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      exerciseId: map['exercise_id'] as String?,
      score: (map['score'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      takenAt: DateTime.fromMillisecondsSinceEpoch(
          (map['taken_at'] as num?)?.toInt() ?? 0),
    );
  }
}
