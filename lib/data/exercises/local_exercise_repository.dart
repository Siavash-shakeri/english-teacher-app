// lib/data/exercises/local_exercise_repository.dart
//
// پیاده‌سازی محلی (SQLite) قرارداد [ExerciseRepository].
//
// - مجموعه‌ها در جدول `exercises` و نمره‌ها در جدول `scores`،
//   فقط برای حساب فعال، ذخیره می‌شوند.
// - شناسهٔ حساب فعال از SharedPreferences با همان کلیدی می‌آید که
//   [LocalAuthRepository.activeAccountKey] تعریف می‌کند.
// - حذف مجموعه، نرم (`is_deleted = 1`) است.
// - این فایل اسکیما را تغییر نمی‌دهد.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/domain/models/exercise.dart';
import 'package:english_teacher/domain/repositories/exercise_repository.dart';

/// پیاده‌سازی محلی مخزن تمرین‌ها روی SQLite + SharedPreferences.
class LocalExerciseRepository implements ExerciseRepository {
  /// خواندن شناسهٔ حساب فعال.
  Future<String> _activeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(LocalAuthRepository.activeAccountKey);
    if (id == null || id.isEmpty) {
      throw StateError('no active account');
    }
    return id;
  }

  @override
  Future<ExerciseSet> saveSet({
    required String type,
    required String title,
    required List<QuizQuestion> questions,
  }) async {
    final accountId = await _activeAccountId();
    final now = DateTime.now();
    final set = ExerciseSet(
      id: const Uuid().v4(),
      accountId: accountId,
      type: type,
      title: title.trim().isEmpty ? 'تمرین' : title.trim(),
      questions: questions,
      createdAt: now,
      updatedAt: now,
    );
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'exercises',
      set.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return set;
  }

  @override
  Future<List<ExerciseSet>> listSets() async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'exercises',
      where: 'account_id = ? AND is_deleted = 0',
      whereArgs: [accountId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ExerciseSet.fromMap).toList();
  }

  @override
  Future<void> deleteSet(String id) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'exercises',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND account_id = ?',
      whereArgs: [id, accountId],
    );
  }

  @override
  Future<ScoreRecord> recordScore({
    required String? exerciseId,
    required double score,
    required double total,
  }) async {
    final accountId = await _activeAccountId();
    final now = DateTime.now();
    final record = ScoreRecord(
      id: const Uuid().v4(),
      accountId: accountId,
      exerciseId: exerciseId,
      score: score,
      total: total,
      takenAt: now,
    );
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'scores',
      {
        'id': record.id,
        'account_id': accountId,
        'exercise_id': exerciseId,
        'score': score,
        'total': total,
        'taken_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record;
  }

  @override
  Future<List<ScoreRecord>> listScores({int limit = 50}) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'scores',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'taken_at DESC',
      limit: limit,
    );
    return rows.map(ScoreRecord.fromMap).toList();
  }

  @override
  Future<double?> averagePercent() async {
    final scores = await listScores(limit: 200);
    if (scores.isEmpty) return null;
    var sum = 0.0;
    for (final s in scores) {
      sum += s.percent;
    }
    return sum / scores.length;
  }
}
