// lib/presentation/screens/exercises/history_screen.dart
//
// تاریخچهٔ آزمون‌ها و نمره‌ها (مرحلهٔ ۶).

import 'package:flutter/material.dart';

import 'package:english_teacher/data/exercises/local_exercise_repository.dart';
import 'package:english_teacher/domain/models/exercise.dart';
import 'package:english_teacher/presentation/widgets/fa_digits.dart';

/// فهرست نمره‌های ثبت‌شدهٔ حساب فعال، از جدیدترین به قدیمی‌ترین.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = LocalExerciseRepository();
  List<ScoreRecord> _scores = [];
  Map<String, String> _titles = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final scores = await _repo.listScores(limit: 100);
      final sets = await _repo.listSets();
      if (!mounted) return;
      setState(() {
        _scores = scores;
        _titles = {for (final s in sets) s.id: s.title};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف تاریخچه؟'),
        content: const Text(
            'همهٔ مجموعه‌های تمرین و نمره‌های این حساب پاک می‌شوند.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('انصراف')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    for (final s in await _repo.listSets()) {
      await _repo.deleteSet(s.id);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تاریخچهٔ آزمون‌ها'),
        actions: [
          if (_scores.isNotEmpty)
            IconButton(
              tooltip: 'حذف تاریخچه',
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _scores.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'هنوز آزمونی ثبت نشده 🙂\nاز تب «تمرین»، «آزمون تازه» بساز.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, height: 2),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final s = _scores[i];
                    final pct = s.percent.round();
                    final color = pct >= 80
                        ? Colors.green
                        : pct >= 50
                            ? Colors.orange
                            : Colors.red;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              color.withValues(alpha: 0.15),
                          child: Text(
                            toFaDigits('$pct'),
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        title: Text(
                            _titles[s.exerciseId] ?? 'تمرین'),
                        subtitle: Text(
                          '${toFaDigits('${s.score.round()}')} از '
                          '${toFaDigits('${s.total.round()}')}'
                          ' • ${faDateTime(s.takenAt)}',
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
