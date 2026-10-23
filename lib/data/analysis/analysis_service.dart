// lib/data/analysis/analysis_service.dart
//
// قرارداد موتورهای تحلیل گرامری مشق‌ها (مرحلهٔ ۴ — قواعد).
//
// در مرحلهٔ ۵، موتور Gemini به پیاده‌سازی واقعی سیم‌کشی شد: با کلید
// ذخیره‌شده در تنظیمات، تحلیل واقعی از Gemini می‌گیرد و در قالب ساخت‌یافته
// برمی‌گرداند. بدون کلید، صادقانه خطای فارسی می‌دهد و هیچ‌وقت نتیجهٔ جعلی
// برنمی‌گرداند.
//
// الگوی این فایل همان `ocr_service.dart` (مرحلهٔ ۲) و
// `translate_service.dart` (مرحلهٔ ۳) است.

import 'dart:convert';

import 'package:english_teacher/data/ai/ai_gate.dart';
import 'package:english_teacher/data/ai/gemini_client.dart';

/// تحلیل گرامری یک جملهٔ انگلیسی.
class SentenceAnalysis {
  /// خود جمله (انگلیسی)
  final String sentence;

  /// زمان/ساختار تشخیص‌داده‌شده (مثلاً «گذشتهٔ ساده») — به فارسی
  final String tense;

  /// فرمول ساختاری جمله — به فارسی/انگلیسی
  final String structure;

  /// یادداشت تکمیلی (مثلاً اصلاح اشتباه کاربر با دلیل)؛ اختیاری
  final String? note;

  const SentenceAnalysis({
    required this.sentence,
    required this.tense,
    required this.structure,
    this.note,
  });
}

/// پیش‌نویس قاعده‌ای که موتور تحلیل پیشنهاد می‌دهد.
class RuleDraft {
  final String category;
  final String title;
  final String explanation;
  final String? formula;
  final List<String> examples;
  final List<String> commonMistakes;

  const RuleDraft({
    required this.category,
    required this.title,
    required this.explanation,
    this.formula,
    this.examples = const [],
    this.commonMistakes = const [],
  });
}

/// اصلاح اشتباه کاربر در یک جمله.
class Correction {
  /// جملهٔ اصلی کاربر
  final String original;

  /// بخش اشتباه جمله
  final String wrongPart;

  /// شکل درست آن بخش
  final String correctPart;

  /// دلیل فارسی اصلاح
  final String reason;

  const Correction({
    required this.original,
    required this.wrongPart,
    required this.correctPart,
    required this.reason,
  });
}

/// کلمهٔ کلیدی استخراج‌شده از تحلیل، برای افزودن به فلش‌کارت‌ها.
class AnalysisKeyWord {
  final String word;
  final String meaning;
  final String? example;

  const AnalysisKeyWord({
    required this.word,
    required this.meaning,
    this.example,
  });
}

/// نتیجهٔ کامل تحلیل گرامری یک مشق.
class GrammarAnalysisResult {
  /// تحلیل جمله‌به‌جمله
  final List<SentenceAnalysis> sentences;

  /// قواعد پیشنهادی برای ذخیره در «قواعد من»
  final List<RuleDraft> ruleDrafts;

  /// اصلاح اشتباه‌های کاربر با دلیل
  final List<Correction> corrections;

  /// کلمات کلیدی برای افزودن به فلش‌کارت‌ها
  final List<AnalysisKeyWord> keyWords;

  const GrammarAnalysisResult({
    this.sentences = const [],
    this.ruleDrafts = const [],
    this.corrections = const [],
    this.keyWords = const [],
  });
}

/// رابط مشترک موتورهای تحلیل گرامری.
///
/// قرارداد: هر موتور واقعی باید تحلیل واقعی برگرداند؛
/// برگرداندن تحلیل جعلی/ساختگی ممنوع است.
abstract class AnalysisEngine {
  /// شناسهٔ یکتای موتور: 'gemini'
  String get engineId;

  /// نام نمایشی فارسی برای نمایش در رابط کاربری
  String get displayName;

  /// آیا موتور در حال حاضر قابل استفاده است؟
  bool get isAvailable;

  /// دلیل فارسی در دسترس نبودن؛ فقط وقتی معنا دارد که [isAvailable] نادرست باشد
  String get unavailableReason;

  /// تحلیل گرامری کامل متن انگلیسی یک مشق به فارسی.
  /// ورودی خالی/فاصله فقط، بدون فراخوانی موتور، نتیجهٔ خالی برمی‌گرداند.
  /// در صورت ناموفق بودن، خطا (با پیام فارسی) پرتاب می‌کند.
  Future<GrammarAnalysisResult> analyzeHomework(String text);

  /// آزادسازی منابع موتور (در صورت نیاز)
  Future<void> close();
}

/// موتور تحلیل گرامری مبتنی بر Gemini (مرحلهٔ ۵ — پیاده‌سازی واقعی).
///
/// قرارداد صداقت: این موتور هرگز تحلیل جعلی برنمی‌گرداند.
/// [isAvailable] فقط وقتی درست است که کلید Gemini در تنظیمات ذخیره شده باشد
/// (کش [AiGate.hasKeyCached])؛ در غیر این صورت [analyzeHomework] خطای فارسی
/// پرتاب می‌کند. پاسخ Gemini به‌صورت JSON ساخت‌یافته گرفته و پارس می‌شود؛
/// اگر پارس ناموفق باشد، خطای فارسی می‌دهد (نه نتیجهٔ ساختگی).
class GeminiAnalysisEngine implements AnalysisEngine {
  @override
  String get engineId => 'gemini';

  @override
  String get displayName => 'تحلیل با Gemini';

  @override
  bool get isAvailable => AiGate.hasKeyCached;

  @override
  String get unavailableReason =>
      'برای تحلیل خودکار، کلید Google AI Studio را در تنظیمات وارد کن';

  @override
  Future<GrammarAnalysisResult> analyzeHomework(String text) async {
    if (text.trim().isEmpty) return const GrammarAnalysisResult();
    final client = await AiGate.client();
    if (client == null) throw UnsupportedError(unavailableReason);
    try {
      final raw = await client.generateContent(
        systemPrompt: _analysisPrompt,
        userMessage: text,
      );
      return _parseResult(raw);
    } finally {
      client.close();
    }
  }

  @override
  Future<void> close() async {}

  /// دستور تحلیل — از Gemini فقط JSON می‌خواهد، بدون هیچ متن اضافه.
  static const String _analysisPrompt = '''
تو یک معلم گرامر انگلیسی دقیق برای فارسی‌زبانان هستی. متن انگلیسی کاربر را تحلیل کن و فقط و فقط یک JSON معتبر برگردان (بدون هیچ متن قبل/بعد، بدون بلاک کد).

ساختار JSON:
{
  "sentences": [{"sentence": "جمله اصلی", "tense": "زمان/ساختار به فارسی", "structure": "فرمول جمله", "note": "یادداشت یا خالی"}],
  "ruleDrafts": [{"category": "دسته (مثل: زمان‌ها، حروف اضافه، جملات شرطی)", "title": "عنوان قاعده", "explanation": "توضیح کامل فارسی با دلیل", "formula": "فرمول یا خالی", "examples": ["مثال انگلیسی — ترجمه فارسی"], "commonMistakes": ["اشتباه رایج فارسی‌زبانان"]}],
  "corrections": [{"original": "جمله اصلی کاربر", "wrongPart": "بخش اشتباه", "correctPart": "شکل درست", "reason": "دلیل فارسی اصلاح"}],
  "keyWords": [{"word": "کلمه", "meaning": "معنی فارسی", "example": "مثال کوتاه"}]
}

قوانین:
- همهٔ توضیح‌ها به فارسی.
- برای هر جمله: tense (مثل «گذشتهٔ ساده»)، structure (فرمول ساختار).
- ۳ تا ۵ مثال جدید با ترجمه برای هر قاعدهٔ مهم.
- اشتباهات رایج مخصوص فارسی‌زبانان.
- اگر جمله‌ای اشتباه گرامری دارد، در corrections با دلیل اصلاح کن.
- keyWords: کلمات مهم و جدید متن با معنی و مثال.
- اگر متن خالی است، هر چهار آرایه را خالی برگردان.
''';

  /// پارس دفاعی پاسخ — در صورت نامعتبر بودن، خطای فارسی (نه نتیجهٔ جعلی).
  GrammarAnalysisResult _parseResult(String raw) {
    var jsonText = raw.trim();
    // حذف بلاک کد مارک‌داون در صورت وجود
    if (jsonText.startsWith('```')) {
      final start = jsonText.indexOf('{');
      final end = jsonText.lastIndexOf('}');
      if (start >= 0 && end > start) {
        jsonText = jsonText.substring(start, end + 1);
      }
    }
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonText) as Map<String, dynamic>;
    } catch (_) {
      throw const GeminiException(
        'پاسخ هوش مصنوعی قابل خواندن نبود؛ دوباره تلاش کن',
      );
    }

    List<SentenceAnalysis> sentences = [];
    for (final s in (decoded['sentences'] as List<dynamic>? ?? [])) {
      final m = s as Map<String, dynamic>;
      sentences.add(SentenceAnalysis(
        sentence: '${m['sentence'] ?? ''}',
        tense: '${m['tense'] ?? ''}',
        structure: '${m['structure'] ?? ''}',
        note: (m['note'] as String?)?.isEmpty == true ? null : m['note'] as String?,
      ));
    }

    List<RuleDraft> ruleDrafts = [];
    for (final r in (decoded['ruleDrafts'] as List<dynamic>? ?? [])) {
      final m = r as Map<String, dynamic>;
      ruleDrafts.add(RuleDraft(
        category: '${m['category'] ?? 'متفرقه'}',
        title: '${m['title'] ?? ''}',
        explanation: '${m['explanation'] ?? ''}',
        formula: (m['formula'] as String?)?.isEmpty == true
            ? null
            : m['formula'] as String?,
        examples: _stringList(m['examples']),
        commonMistakes: _stringList(m['commonMistakes']),
      ));
    }

    List<Correction> corrections = [];
    for (final c in (decoded['corrections'] as List<dynamic>? ?? [])) {
      final m = c as Map<String, dynamic>;
      corrections.add(Correction(
        original: '${m['original'] ?? ''}',
        wrongPart: '${m['wrongPart'] ?? ''}',
        correctPart: '${m['correctPart'] ?? ''}',
        reason: '${m['reason'] ?? ''}',
      ));
    }

    List<AnalysisKeyWord> keyWords = [];
    for (final k in (decoded['keyWords'] as List<dynamic>? ?? [])) {
      final m = k as Map<String, dynamic>;
      keyWords.add(AnalysisKeyWord(
        word: '${m['word'] ?? ''}',
        meaning: '${m['meaning'] ?? ''}',
        example: (m['example'] as String?)?.isEmpty == true
            ? null
            : m['example'] as String?,
      ));
    }

    return GrammarAnalysisResult(
      sentences: sentences,
      ruleDrafts: ruleDrafts,
      corrections: corrections,
      keyWords: keyWords,
    );
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) return [];
    return [for (final e in value) '$e'];
  }
}
