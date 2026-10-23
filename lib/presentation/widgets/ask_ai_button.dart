// lib/presentation/widgets/ask_ai_button.dart
//
// دکمهٔ «بپرس از هوش مصنوعی» — کنار هر جمله (در مشق) و هر قاعده (در «قواعد من»).
// - اگر کلید Gemini ذخیره شده باشد: صفحهٔ چت با پیام اولیهٔ آماده باز می‌شود.
// - اگر کلیدی نباشد: با یک پیام فارسی، کاربر به صفحهٔ تنظیمات هدایت می‌شود.

import 'package:flutter/material.dart';

import 'package:english_teacher/data/ai/ai_gate.dart';
import 'package:english_teacher/domain/models/grammar_rule.dart';
import 'package:english_teacher/presentation/screens/ai_tutor/ai_tutor_screen.dart';
import 'package:english_teacher/presentation/screens/settings/settings_screen.dart';

/// ابزار باز کردن چت معلم با بافت آماده.
class AskAi {
  /// باز کردن چت با بافت یک جملهٔ انگلیسی.
  static Future<void> fromSentence(
      BuildContext context, String sentence) async {
    await _open(
      context,
      'این جمله را برایم توضیح بده (معنی، گرامر و نکاتش):\n$sentence',
    );
  }

  /// باز کردن چت با بافت یک قاعدهٔ گرامری.
  static Future<void> fromRule(BuildContext context, GrammarRule rule) async {
    final formula = (rule.formula ?? '').isEmpty ? '' : '\nفرمول: ${rule.formula}';
    await _open(
      context,
      'این قاعدهٔ گرامری را کامل توضیح بده (کاربرد، مثال‌های بیشتر، اشتباهات رایج):\n'
      '[${rule.category}] ${rule.title}\n'
      '${rule.explanation}$formula',
    );
  }

  static Future<void> _open(BuildContext context, String prompt) async {
    final client = await AiGate.client();
    if (client == null) {
      if (!context.mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('کلید وارد نشده'),
          content: const Text(
            'برای پرسیدن از معلم هوش مصنوعی، اول کلید Google AI Studio را در تنظیمات وارد کن.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('بعداً'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('رفتن به تنظیمات'),
            ),
          ],
        ),
      );
      if (go == true && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      }
      return;
    }
    client.close();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiTutorScreen(initialPrompt: prompt),
      ),
    );
  }
}
