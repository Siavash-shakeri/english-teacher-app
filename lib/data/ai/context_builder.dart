// lib/data/ai/context_builder.dart
//
// سازندهٔ دستور سیستمی (system prompt) برای معلم هوش مصنوعی.
// قبل از هر درخواست، خلاصه‌ای فشرده از «قواعد من» و مشق‌های حساب فعال
// را به دستور تزریق می‌کند تا معلم به داده‌های همان کاربر دسترسی داشته باشد.
//
// سقف‌ها (برای کنترل طول پرامپت — مستندشده و قابل تنظیم):
// - حداکثر ۲۰ قاعده: اول ستاره‌دارها، بعد جدیدترین‌ها؛ توضیح هر قاعده
//   حداکثر ۳۰۰ نویسه.
// - حداکثر ۱۰ مشق اخیر؛ متن استخراج‌شدهٔ هر مشق حداکثر ۱۵۰۰ نویسه.
// با این سقف‌ها، بافت تزریق‌شده معمولاً زیر ~۲۵هزار نویسه می‌ماند.

import 'package:english_teacher/data/grammar/local_grammar_repository.dart';
import 'package:english_teacher/data/homework/local_homework_repository.dart';
import 'package:english_teacher/domain/models/grammar_rule.dart';

/// سازندهٔ بافت (context) معلم هوش مصنوعی.
class ContextBuilder {
  static const int maxRules = 20;
  static const int maxRuleExplanationChars = 300;
  static const int maxHomeworks = 10;
  static const int maxHomeworkTextChars = 1500;

  final LocalGrammarRepository _grammar;
  final LocalHomeworkRepository _homeworks;

  ContextBuilder({
    LocalGrammarRepository? grammar,
    LocalHomeworkRepository? homeworks,
  })  : _grammar = grammar ?? LocalGrammarRepository(),
        _homeworks = homeworks ?? LocalHomeworkRepository();

  String _truncate(String text, int max) =>
      text.length <= max ? text : '${text.substring(0, max)}…';

  /// دستور سیستمی کامل برای معلم هوش مصنوعی.
  Future<String> buildSystemPrompt() async {
    final buffer = StringBuffer(
      'تو «معلم انگلیسی من» هستی؛ یک معلم انگلیسی صبور و دقیق برای یک '
      'فارسی‌زبان. همیشه به فارسی پاسخ بده مگر اینکه کاربر صریحاً انگلیسی '
      'بخواهد. پاسخ‌ها کوتاه، شفاف و با مثال باشند. وقتی جمله‌ای را تصحیح '
      'می‌کنی، دلیل قاعده را هم بگو. از ایموجی کم استفاده کن.',
    );

    // ── قواعد من ──
    try {
      final rules = await _grammar.listRules();
      final picked = _pickRules(rules);
      if (picked.isNotEmpty) {
        buffer.writeln('\n\nقواعدی که این کاربر قبلاً دیده (از «قواعد من»):');
        for (final r in picked) {
          buffer.writeln(
            '- [${r.category}] ${r.title}: '
            '${_truncate(r.explanation, maxRuleExplanationChars)}',
          );
        }
        buffer.writeln(
          'اگر کاربر دربارهٔ یکی از این قواعد پرسید، به همین توضیحِ ذخیره‌شده '
          'ارجاع بده و تکرارش نکن.',
        );
      }
    } catch (_) {
      // بدون بافت قواعد ادامه بده
    }

    // ── مشق‌ها ──
    try {
      final homeworks = await _homeworks.listHomeworks();
      final picked = homeworks.take(maxHomeworks).toList();
      if (picked.isNotEmpty) {
        buffer.writeln('\n\nمشق‌های اخیر این کاربر:');
        for (final h in picked) {
          final text = h.extractedText.trim();
          buffer.writeln(
            '- «${h.title}»: ${_truncate(text, maxHomeworkTextChars)}',
          );
        }
        buffer.writeln(
          'می‌توانی به این مشق‌ها ارجاع بدهی و جمله‌هایشان را تصحیح کنی.',
        );
      }
    } catch (_) {
      // بدون بافت مشق ادامه بده
    }

    return buffer.toString();
  }

  /// انتخاب حداکثر [maxRules] قاعده: اول ستاره‌دارها، بعد جدیدترین‌ها.
  List<GrammarRule> _pickRules(List<GrammarRule> rules) {
    final sorted = List.of(rules)
      ..sort((a, b) {
        if (a.isStarred != b.isStarred) return a.isStarred ? -1 : 1;
        return b.firstSeenAt.compareTo(a.firstSeenAt);
      });
    return sorted.take(maxRules).toList();
  }
}
