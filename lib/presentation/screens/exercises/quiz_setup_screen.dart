// lib/presentation/screens/exercises/quiz_setup_screen.dart
//
// صفحهٔ تنظیم آزمون تازه (مرحلهٔ ۶).
// نوع‌های سؤال + تعداد انتخاب می‌شود، بعد آزمون ساخته و اجرا می‌شود.

import 'package:flutter/material.dart';

import 'package:english_teacher/data/exercises/exercise_generator.dart';
import 'package:english_teacher/data/exercises/local_exercise_repository.dart';
import 'package:english_teacher/data/homework/local_homework_repository.dart';
import 'package:english_teacher/data/vocabulary/local_vocabulary_repository.dart';
import 'package:english_teacher/domain/models/exercise.dart';
import 'package:english_teacher/domain/models/homework.dart';
import 'package:english_teacher/presentation/screens/exercises/quiz_screen.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// صفحهٔ ساخت آزمون تازه.
///
/// اگر [homework] داده شود، آزمون فقط از همان مشق ساخته می‌شود
/// (ورودی دکمهٔ «📝 تمرین بساز» در صفحهٔ جزئیات مشق).
class QuizSetupScreen extends StatefulWidget {
  final Homework? homework;

  const QuizSetupScreen({super.key, this.homework});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  final _types = <String>{
    ExerciseType.fillBlank,
    ExerciseType.multipleChoice,
    ExerciseType.wordOrder,
    ExerciseType.translation,
  };
  int _count = 10;
  bool _busy = false;
  String? _error;

  Future<void> _start() async {
    if (_types.isEmpty) {
      setState(() => _error = 'حداقل یک نوع تمرین انتخاب کن 🙂');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final homeworks = widget.homework != null
          ? [widget.homework!]
          : await LocalHomeworkRepository().listHomeworks();
      final words = await LocalVocabularyRepository().listWords();
      final questions = ExerciseGenerator(
        homeworks: homeworks,
        words: words,
      ).generate(types: _types, count: _count);

      final set = await LocalExerciseRepository().saveSet(
        type: _types.length == 1 ? _types.first : 'mixed',
        title: widget.homework != null
            ? 'تمرین «${widget.homework!.title}»'
            : 'تمرین ${toFaDigits('${questions.length}')} سؤالی',
        questions: questions,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => QuizScreen(set: set)),
      );
    } on QuizDataShortage catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'خطایی رخ داد؛ دوباره تلاش کن.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('آزمون تازه')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.homework != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.book_outlined),
                title: Text('از مشق «${widget.homework!.title}»'),
                subtitle: const Text('سؤال‌ها فقط از همین مشق ساخته می‌شوند'),
              ),
            ),
          const SizedBox(height: 8),
          const Text('نوع‌های تمرین',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ExerciseType.all)
                FilterChip(
                  label: Text(ExerciseType.faName(t)),
                  selected: _types.contains(t),
                  onSelected: (sel) => setState(() {
                    sel ? _types.add(t) : _types.remove(t);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('تعداد سؤال',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('۵')),
              ButtonSegment(value: 10, label: Text('۱۰')),
              ButtonSegment(value: 15, label: Text('۱۵')),
            ],
            selected: {_count},
            onSelectionChanged: (s) => setState(() => _count = s.first),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(_busy ? 'در حال ساخت…' : 'شروع آزمون'),
          ),
          const SizedBox(height: 8),
          const Text(
            'سؤال‌ها از مشق‌ها و کلمه‌های خودت ساخته می‌شوند؛ '
            'هرچه داده بیشتر باشد، آزمون متنوع‌تر است.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
