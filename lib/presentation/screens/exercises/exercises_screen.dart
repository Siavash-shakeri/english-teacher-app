// lib/presentation/screens/exercises/exercises_screen.dart
//
// تب «تمرین» (مرحلهٔ ۶): نقطهٔ شروع آزمون تازه، مرور امروز،
// نمودار پیشرفت و تاریخچه.

import 'package:flutter/material.dart';

import 'package:english_teacher/data/exercises/local_exercise_repository.dart';
import 'package:english_teacher/data/review/spaced_repetition.dart';
import 'package:english_teacher/presentation/screens/exercises/history_screen.dart';
import 'package:english_teacher/presentation/screens/exercises/quiz_setup_screen.dart';
import 'package:english_teacher/presentation/screens/exercises/review_screen.dart';
import 'package:english_teacher/presentation/screens/exercises/score_chart.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// صفحهٔ اصلی تب تمرین.
class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  int? _due;
  double? _avg;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    int? due;
    double? avg;
    try {
      due = await SpacedRepetition().dueCount();
    } catch (_) {}
    try {
      avg = await LocalExerciseRepository().averagePercent();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _due = due;
        _avg = avg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تمرین 📝')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // آزمون تازه
            Card(
              child: ListTile(
                leading: const Icon(Icons.quiz_outlined, size: 32),
                title: const Text('آزمون تازه',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                subtitle: const Text(
                    'جای خالی، تستی، مرتب‌سازی کلمات و ترجمه — از مشق‌ها و کلمه‌های خودت'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const QuizSetupScreen()))
                    .then((_) => _refresh()),
              ),
            ),
            const SizedBox(height: 12),
            // مرور امروز
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_edu_outlined, size: 32),
                title: const Text('مرور امروز',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                subtitle: Text(_due == null
                    ? 'تکرار با فاصلهٔ زمانی'
                    : _due == 0
                        ? 'همهٔ مرورها انجام شده 🎉'
                        : '${toFaDigits('$_due')} کارت در انتظار مرور'),
                trailing: _due != null && _due! > 0
                    ? CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: Text(toFaDigits('$_due!'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                      )
                    : const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(
                        builder: (_) => const ReviewScreen()))
                    .then((_) => _refresh()),
              ),
            ),
            const SizedBox(height: 12),
            // پیشرفت من
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('پیشرفت من 📊',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        const Spacer(),
                        if (_avg != null)
                          Chip(
                            label: Text(
                                'میانگین ${toFaDigits('${_avg!.round()}٪')}'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder(
                      future:
                          LocalExerciseRepository().listScores(limit: 12),
                      builder: (c, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 120,
                            child: Center(
                                child: CircularProgressIndicator()),
                          );
                        }
                        return ScoreChart(
                            scores: snap.data ?? const []);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // تاریخچه
            Card(
              child: ListTile(
                leading: const Icon(Icons.timeline_outlined, size: 32),
                title: const Text('تاریخچهٔ آزمون‌ها',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                subtitle:
                    const Text('نمره‌های قبلی و حذف تاریخچه'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const HistoryScreen())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
