// lib/domain/repositories/exercise_repository.dart
//
// قرارداد لایهٔ دامنه برای «تمرین‌ها و نمره‌ها» (مرحلهٔ ۶).
// همهٔ عملیات در محدودهٔ حساب فعال انجام می‌شوند؛ حذف، نرم است.

import 'package:english_teacher/domain/models/exercise.dart';

/// قرارداد دسترسی به مجموعه‌های تمرین و نمره‌ها.
abstract class ExerciseRepository {
  /// ذخیرهٔ یک مجموعهٔ تمرینِ تازه‌تولیدشده برای حساب فعال.
  Future<ExerciseSet> saveSet({
    required String type,
    required String title,
    required List<QuizQuestion> questions,
  });

  /// مجموعه‌های حساب فعالِ حذف‌نشده، از جدیدترین به قدیمی‌ترین.
  Future<List<ExerciseSet>> listSets();

  /// حذف نرم یک مجموعه (فقط در محدودهٔ حساب فعال).
  Future<void> deleteSet(String id);

  /// ثبت نمرهٔ یک آزمونِ تمام‌شده در جدول `scores`.
  Future<ScoreRecord> recordScore({
    required String? exerciseId,
    required double score,
    required double total,
  });

  /// نمره‌های حساب فعال، از جدیدترین به قدیمی‌ترین.
  Future<List<ScoreRecord>> listScores({int limit = 50});

  /// میانگین درصد نمره‌های حساب فعال؛ اگر نمره‌ای نباشد تهی.
  Future<double?> averagePercent();
}
