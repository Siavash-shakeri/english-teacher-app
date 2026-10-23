// lib/data/exercises/exercise_generator.dart
//
// تولیدکنندهٔ آفلاین تمرین از داده‌های خودِ کاربر (مرحلهٔ ۶).
//
// - همهٔ سؤال‌ها از مشق‌ها (جمله‌ها) و دفتر واژگانِ حساب فعال
//   ساخته می‌شوند؛ هیچ محتوایی جعل نمی‌شود.
// - اگر داده کافی نباشد، [QuizDataShortage] با پیام فارسی پرتاب می‌شود
//   تا رابط کاربری به‌جای آزمون خالی، راهنمایی نشان دهد.
// - با `seed` می‌توان تولید را تکرارپذیر (قابل تست) کرد؛
//   در استفادهٔ عادی، seed تهی یعنی تصادفی واقعی.

import 'dart:math';

import 'package:english_teacher/data/translate/sentence_splitter.dart';
import 'package:english_teacher/domain/models/exercise.dart';
import 'package:english_teacher/domain/models/homework.dart';
import 'package:english_teacher/domain/models/word.dart';

/// خطای کمبود داده برای ساخت تمرین؛ پیام آن فارسی و قابل نمایش است.
class QuizDataShortage implements Exception {
  final String message;
  const QuizDataShortage(this.message);
  @override
  String toString() => message;
}

/// تولیدکنندهٔ تمرین؛ خالص و بدون وابستگی به دیتابیس.
///
/// `homeworks` و `words` باید از قبل برای حساب فعال خوانده شده باشند.
class ExerciseGenerator {
  final List<Homework> homeworks;
  final List<Word> words;
  final Random _random;

  ExerciseGenerator({
    required this.homeworks,
    required this.words,
    int? seed,
  }) : _random = seed == null ? Random() : Random(seed);

  /// کلمات رایج انگلیسی که برای «جای خالی» مناسب نیستند.
  static const Set<String> _stopwords = {
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'to', 'of', 'in', 'on', 'at', 'for', 'with', 'and', 'or', 'but',
    'not', 'no', 'it', 'its', 'this', 'that', 'these', 'those',
    'he', 'she', 'they', 'we', 'you', 'i', 'me', 'him', 'her',
    'us', 'them', 'my', 'your', 'his', 'our', 'their',
    'as', 'by', 'from', 'do', 'does', 'did', 'done',
    'have', 'has', 'had', 'having', 'will', 'would', 'can', 'could',
    'shall', 'should', 'may', 'might', 'must',
    'so', 'if', 'then', 'than', 'too', 'very', 'just', 'also',
    'only', 'there', 'here', 'when', 'where', 'which', 'who',
    'whom', 'whose', 'what', 'how', 'why', 'am',
  };

  /// همهٔ جمله‌های مشق‌ها (تمیز و با حداقل طول).
  List<String> _sentences({int minWords = 4}) {
    final out = <String>[];
    for (final hw in homeworks) {
      for (final s in SentenceSplitter.split(hw.extractedText)) {
        final t = s.trim();
        if (t.isEmpty) continue;
        final tokens = _tokens(t);
        if (tokens.length >= minWords) out.add(t);
      }
    }
    return out;
  }

  /// توکن‌های یک جمله: فقط حروف و آپاستروف نگه داشته می‌شود.
  static List<String> _tokens(String sentence) {
    return sentence
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r"^[^A-Za-z']+|[^A-Za-z']+$"), ''))
        .where((w) => w.isNotEmpty)
        .toList();
  }

  /// آیا کلمه برای «جای خالی» مناسب است؟
  static bool _blankable(String word) {
    final lower = word.toLowerCase();
    return lower.length >= 4 && !_stopwords.contains(lower);
  }

  /// تولید آزمون.
  ///
  /// [types] زیرمجموعه‌ای از [ExerciseType.all] و [count] تعداد
  /// سؤال‌های درخواستی است. سؤال‌ها به‌صورت نوبتی بین نوع‌های
  /// درخواستی توزیع می‌شوند؛ نوعی که دادهٔ کافی ندارد رد می‌شود.
  /// اگر هیچ سؤالی ساخته نشود، [QuizDataShortage] پرتاب می‌شود.
  List<QuizQuestion> generate({
    required Set<String> types,
    required int count,
  }) {
    final wanted =
        types.where((t) => ExerciseType.all.contains(t)).toList();
    if (wanted.isEmpty) {
      throw const QuizDataShortage(
          'نوع تمرینی انتخاب نشده است.');
    }

    final questions = <QuizQuestion>[];
    var guard = 0;
    var typeIndex = 0;
    // guard جلوی حلقهٔ بی‌نهایت را می‌گیرد وقتی داده کم است
    while (questions.length < count && guard < count * 12) {
      guard++;
      final type = wanted[typeIndex % wanted.length];
      typeIndex++;
      final q = _tryBuild(type);
      if (q != null && !_duplicate(questions, q)) {
        questions.add(q);
      }
    }

    if (questions.isEmpty) {
      throw const QuizDataShortage(
        'برای ساخت تمرین، اول چند مشق اسکن کن و چند کلمه به دفتر '
        'واژگان اضافه کن 🙂',
      );
    }
    return questions;
  }

  /// جلوگیری از سؤال تکراری در یک آزمون.
  static bool _duplicate(List<QuizQuestion> list, QuizQuestion q) {
    return list.any((e) => e.type == q.type && e.prompt == q.prompt);
  }

  QuizQuestion? _tryBuild(String type) {
    switch (type) {
      case ExerciseType.fillBlank:
        return _fillBlank();
      case ExerciseType.multipleChoice:
        return _multipleChoice();
      case ExerciseType.wordOrder:
        return _wordOrder();
      case ExerciseType.translation:
        return _translation();
      default:
        return null;
    }
  }

  /// جای خالی: جمله‌ای از مشق‌ها + حذف یک کلمهٔ محتوایی.
  QuizQuestion? _fillBlank() {
    final sentences = _sentences(minWords: 4);
    if (sentences.isEmpty) return null;
    final vocab = words.map((w) => w.word.toLowerCase()).toSet();

    // چند جملهٔ تصادفی را امتحان کن تا یکی سؤال‌شدنی باشد
    final tries = sentences.toList()..shuffle(_random);
    for (final sentence in tries.take(8)) {
      final tokens = _tokens(sentence);
      final candidates =
          tokens.where(_blankable).toList();
      if (candidates.isEmpty) continue;

      // ترجیح: کلمه‌ای که در دفتر واژگان هم هست
      candidates.sort((a, b) {
        final aIn = vocab.contains(a.toLowerCase()) ? 0 : 1;
        final bIn = vocab.contains(b.toLowerCase()) ? 0 : 1;
        if (aIn != bIn) return aIn - bIn;
        return b.length - a.length;
      });
      final answer = candidates.first;

      // سه گزینهٔ غلط از بقیهٔ کلمه‌های متن‌ها
      final pool = <String>{};
      for (final s in sentences) {
        for (final t in _tokens(s)) {
          final lower = t.toLowerCase();
          if (_blankable(t) && lower != answer.toLowerCase()) {
            pool.add(t);
          }
        }
      }
      if (pool.length < 3) continue;
      final distractors = pool.toList()..shuffle(_random);

      final prompt = sentence.replaceFirst(
        RegExp('\\b${RegExp.escape(answer)}\\b', caseSensitive: false),
        '___',
      );
      final options = [answer, ...distractors.take(3)]..shuffle(_random);
      return QuizQuestion(
        type: ExerciseType.fillBlank,
        prompt: prompt,
        options: options,
        answer: answer,
      );
    }
    return null;
  }

  /// تستی انگلیسی → فارسی: کلمه نشان داده می‌شود، معنی انتخاب می‌شود.
  QuizQuestion? _multipleChoice() {
    if (words.length < 4) return null;
    final pool = words.toList()..shuffle(_random);
    final target = pool.first;
    final others = pool.skip(1).take(3).map((w) => w.meaning).toList();
    if (others.length < 3) return null;
    final options = [target.meaning, ...others]..shuffle(_random);
    return QuizQuestion(
      type: ExerciseType.multipleChoice,
      prompt: 'معنی «${target.word}» چیست؟',
      options: options,
      answer: target.meaning,
      hint: target.example,
    );
  }

  /// تستی فارسی → انگلیسی: معنی نشان داده می‌شود، کلمه انتخاب می‌شود.
  QuizQuestion? _translation() {
    if (words.length < 4) return null;
    final pool = words.toList()..shuffle(_random);
    final target = pool.first;
    final others = pool.skip(1).take(3).map((w) => w.word).toList();
    if (others.length < 3) return null;
    final options = [target.word, ...others]..shuffle(_random);
    return QuizQuestion(
      type: ExerciseType.translation,
      prompt: 'کدام گزینه ترجمهٔ «${target.meaning}» است؟',
      options: options,
      answer: target.word,
      hint: target.example,
    );
  }

  /// مرتب‌سازی کلمات: جمله‌ای ۳ تا ۸ کلمه‌ای به‌هم‌ریخته می‌شود.
  QuizQuestion? _wordOrder() {
    final sentences = _sentences(minWords: 3);
    final usable = sentences
        .where((s) {
          final n = _tokens(s).length;
          return n >= 3 && n <= 8;
        })
        .toList();
    if (usable.isEmpty) return null;
    final sentence = usable[_random.nextInt(usable.length)];
    final tokens = _tokens(sentence);
    final shuffled = tokens.toList()..shuffle(_random);
    // اگر به‌هم‌ریختن اتفاقی همان ترتیب درست شد، یک‌بار دیگر
    if (shuffled.join(' ') == tokens.join(' ') && tokens.length > 1) {
      final last = shuffled.removeLast();
      shuffled.insert(0, last);
    }
    return QuizQuestion(
      type: ExerciseType.wordOrder,
      prompt: 'کلمات را به ترتیب درست بچینید:',
      options: shuffled,
      answer: tokens.join(' '),
    );
  }
}
