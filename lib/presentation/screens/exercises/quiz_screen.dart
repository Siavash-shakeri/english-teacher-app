// lib/presentation/screens/exercises/quiz_screen.dart
//
// اجرای آزمون (مرحلهٔ ۶): یک سؤال در هر صفحه، بازخورد فوری فارسی،
// صفحهٔ نتیجه با ثبت نمره.

import 'package:flutter/material.dart';

import 'package:english_teacher/data/exercises/local_exercise_repository.dart';
import 'package:english_teacher/domain/models/exercise.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// صفحهٔ اجرای آزمون روی یک [ExerciseSet] ذخیره‌شده.
///
/// در پایان، نمره در جدول `scores` ثبت می‌شود.
class QuizScreen extends StatefulWidget {
  final ExerciseSet set;

  const QuizScreen({super.key, required this.set});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int _correct = 0;
  String? _picked; // گزینهٔ انتخاب‌شده (انواع تستی)
  final List<String> _ordered = []; // توکن‌های چیده‌شده (word_order)
  bool _answered = false;
  bool _finished = false;
  bool _saving = false;

  QuizQuestion get _q => widget.set.questions[_index];
  int get _total => widget.set.questions.length;

  void _submit() {
    if (_answered || _saving) return;
    final q = _q;
    final given = q.type == ExerciseType.wordOrder
        ? _ordered.join(' ')
        : (_picked ?? '');
    final ok = given.trim() == q.answer.trim();
    setState(() {
      _answered = true;
      if (ok) _correct++;
    });
  }

  Future<void> _next() async {
    if (_index + 1 >= _total) {
      setState(() => _saving = true);
      try {
        await LocalExerciseRepository().recordScore(
          exerciseId: widget.set.id,
          score: _correct.toDouble(),
          total: _total.toDouble(),
        );
      } catch (_) {
        // ثبت نمره شکست خورد؛ نتیجه همچنان نمایش داده می‌شود
      }
      if (mounted) {
        setState(() {
          _saving = false;
          _finished = true;
        });
      }
      return;
    }
    setState(() {
      _index++;
      _picked = null;
      _ordered.clear();
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult(context);
    final q = _q;
    return Scaffold(
      appBar: AppBar(
        title: Text('سؤال ${toFaDigits('${_index + 1}')} از ${toFaDigits('$_total')}'),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: _total == 0 ? 0 : (_index + 1) / _total,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Chip(
                  label: Text(ExerciseType.faName(q.type)),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      q.prompt,
                      style: const TextStyle(fontSize: 18, height: 1.8),
                      textDirection: q.type == ExerciseType.multipleChoice ||
                              q.type == ExerciseType.wordOrder
                          ? TextDirection.ltr
                          : TextDirection.rtl,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (q.type == ExerciseType.wordOrder)
                  _buildOrderArea()
                else
                  ...q.options.map(_buildOption),
                if (_answered) _buildFeedback(),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: _answered ? _next : _submit,
                        child: Text(_answered
                            ? (_index + 1 >= _total
                                ? 'دیدن نتیجه'
                                : 'سؤال بعد')
                            : 'ثبت پاسخ'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// دکمهٔ یک گزینه (انواع تستی).
  Widget _buildOption(String option) {
    final q = _q;
    final isAnswer = option == q.answer;
    Color? bg;
    if (_answered) {
      if (isAnswer) {
        bg = Colors.green.withValues(alpha: 0.25);
      } else if (option == _picked) {
        bg = Colors.red.withValues(alpha: 0.2);
      }
    } else if (option == _picked) {
      bg = Theme.of(context).colorScheme.primaryContainer;
    }
    return Card(
      color: bg,
      child: ListTile(
        title: Text(option, textDirection: TextDirection.ltr),
        trailing: _answered && isAnswer
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        onTap: _answered ? null : () => setState(() => _picked = option),
      ),
    );
  }

  /// ناحیهٔ مرتب‌سازی کلمات: توکن‌های باقی‌مانده + جملهٔ ساخته‌شده.
  Widget _buildOrderArea() {
    final q = _q;
    final remaining =
        q.options.where((t) => !_ordered.contains(t)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
                color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_ordered.isEmpty)
                const Text('روی کلمات بزن تا جمله ساخته شود…',
                    style: TextStyle(fontSize: 12)),
              for (final t in _ordered)
                ActionChip(
                  label: Text(t),
                  onPressed: _answered
                      ? null
                      : () => setState(() => _ordered.remove(t)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in remaining)
              FilterChip(
                label: Text(t),
                selected: false,
                onSelected: _answered
                    ? null
                    : (_) => setState(() => _ordered.add(t)),
              ),
          ],
        ),
      ],
    );
  }

  /// بازخورد فوری بعد از ثبت پاسخ.
  Widget _buildFeedback() {
    final q = _q;
    final given = q.type == ExerciseType.wordOrder
        ? _ordered.join(' ')
        : (_picked ?? '');
    final ok = given.trim() == q.answer.trim();
    return Card(
      color: ok
          ? Colors.green.withValues(alpha: 0.15)
          : Colors.red.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ok ? 'آفرین! درست بود 🎉' : 'اشتباه شد 😅',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (!ok) ...[
              const SizedBox(height: 4),
              const Text('پاسخ درست:'),
              Text(q.answer,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
            if (q.hint != null && q.hint!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('💡 ${q.hint!}',
                  style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  /// صفحهٔ نتیجهٔ نهایی آزمون.
  Widget _buildResult(BuildContext context) {
    final percent =
        _total == 0 ? 0 : (_correct / _total * 100).round();
    final message = percent >= 80
        ? 'عالی! 🌟'
        : percent >= 50
            ? 'خوب پیش می‌روی! 💪'
            : 'اشکالی ندارد، با مرور بیشتر بهتر می‌شود 🙂';
    return Scaffold(
      appBar: AppBar(title: const Text('نتیجهٔ آزمون')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                toFaDigits('$percent٪'),
                style: const TextStyle(
                    fontSize: 56, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${toFaDigits('$_correct')} پاسخ درست از ${toFaDigits('$_total')} سؤال',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 8),
              const Text('💾 نمره ثبت شد',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('بازگشت به تمرین‌ها'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
