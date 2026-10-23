// lib/domain/models/grammar_rule.dart
//
// مدل دامنهٔ «قاعدهٔ گرامری» در دفتر «قواعد من» (مرحلهٔ ۴ — قواعد).
// هر قاعده متعلق به یک حساب کاربری است و با فرمول، مثال‌ها و
// اشتباهات رایج ذخیره می‌شود. حذف، نرم (`is_deleted`) انجام می‌شود.

import 'dart:convert';

/// نمایندهٔ یک قاعدهٔ گرامری ذخیره‌شده در «قواعد من».
///
/// ردیف جدول `grammar_rules` را می‌خواند؛ زمان‌ها epoch-milliseconds هستند،
/// `examples` و `common_mistakes` به صورت آرایهٔ JSON در TEXT ذخیره می‌شوند.
class GrammarRule {
  /// شناسهٔ یکتای قاعده (UUID نسخهٔ ۴)
  final String id;

  /// شناسهٔ حسابی که این قاعده به آن تعلق دارد
  final String accountId;

  /// دسته‌بندی قاعده (مثلاً «زمان‌ها»، «حروف اضافه»، «جملات شرطی»)
  final String category;

  /// عنوان قاعده (مثلاً «گذشتهٔ ساده»)
  final String title;

  /// توضیح کامل فارسی قاعده، شامل دلیل و منطق آن
  final String explanation;

  /// فرمول جمله (مثلاً «Subject + V2 + …»)؛ اختیاری
  final String? formula;

  /// مثال‌های انگلیسی با ترجمهٔ فارسی؛ هر مورد «متن — ترجمه»
  final List<String> examples;

  /// اشتباهات رایج فارسی‌زبانان دربارهٔ این قاعده؛ اختیاری
  final List<String> commonMistakes;

  /// اولین باری که کاربر این قاعده را دید (epoch-ms)
  final DateTime firstSeenAt;

  /// آیا ستاره‌دار (نشان‌شده) است؟
  final bool isStarred;

  /// زمان آخرین به‌روزرسانی رکورد
  final DateTime updatedAt;

  const GrammarRule({
    required this.id,
    required this.accountId,
    required this.category,
    required this.title,
    required this.explanation,
    this.formula,
    this.examples = const [],
    this.commonMistakes = const [],
    required this.firstSeenAt,
    this.isStarred = false,
    required this.updatedAt,
  });

  /// کلید نرمال‌شدهٔ تکراری‌بودن: دسته + عنوان (trim و بدون حساسیت
  /// به بزرگی/کوچکی حروف). برای تشخیص «قاعدهٔ تکراری» استفاده می‌شود.
  static String dedupeKey(String category, String title) =>
      '${category.trim().toLowerCase()}|${title.trim().toLowerCase()}';

  /// ساخت از یک ردیف جدول `grammar_rules`.
  ///
  /// ستون‌ها: id، account_id، category، title، explanation، formula،
  /// examples (JSON TEXT)، common_mistakes (JSON TEXT)، first_seen_at
  /// (epoch-ms)، is_starred (0/1)، is_deleted، updated_at.
  factory GrammarRule.fromMap(Map<String, Object?> map) {
    List<String> decodeList(Object? raw) {
      if (raw == null) return const [];
      final text = raw as String;
      if (text.trim().isEmpty) return const [];
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return decoded.map((e) => '$e').toList();
        }
      } catch (_) {
        // رشتهٔ غیر-JSON: همان یک مورد را برگردان
        return [text];
      }
      return [text];
    }

    return GrammarRule(
      id: map['id'] as String,
      accountId: map['account_id'] as String,
      category: map['category'] as String? ?? '',
      title: map['title'] as String? ?? '',
      explanation: map['explanation'] as String? ?? '',
      formula: map['formula'] as String?,
      examples: decodeList(map['examples']),
      commonMistakes: decodeList(map['common_mistakes']),
      firstSeenAt: DateTime.fromMillisecondsSinceEpoch(
          (map['first_seen_at'] as num?)?.toInt() ?? 0),
      isStarred: ((map['is_starred'] as num?)?.toInt() ?? 0) == 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as num?)?.toInt() ?? 0),
    );
  }

  /// تبدیل به ردیف قابل درج در جدول `grammar_rules`.
  ///
  /// `is_deleted` همیشه ۰ (زنده) نوشته می‌شود؛ حذف نرم از طریق مخزن
  /// انجام می‌گیرد.
  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'category': category,
        'title': title,
        'explanation': explanation,
        'formula': formula,
        'examples': jsonEncode(examples),
        'common_mistakes': jsonEncode(commonMistakes),
        'first_seen_at': firstSeenAt.millisecondsSinceEpoch,
        'is_starred': isStarred ? 1 : 0,
        'is_deleted': 0,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  /// کپی با تغییرات جزئی (مثلاً تغییر وضعیت ستاره).
  GrammarRule copyWith({
    String? category,
    String? title,
    String? explanation,
    String? formula,
    List<String>? examples,
    List<String>? commonMistakes,
    bool? isStarred,
    DateTime? updatedAt,
  }) {
    return GrammarRule(
      id: id,
      accountId: accountId,
      category: category ?? this.category,
      title: title ?? this.title,
      explanation: explanation ?? this.explanation,
      formula: formula ?? this.formula,
      examples: examples ?? this.examples,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      firstSeenAt: firstSeenAt,
      isStarred: isStarred ?? this.isStarred,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'GrammarRule(id: $id, category: $category, title: $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrammarRule &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
