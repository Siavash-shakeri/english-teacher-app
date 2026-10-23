// lib/data/homework/local_homework_repository.dart
//
// پیاده‌سازی محلی (SQLite) قرارداد [HomeworkRepository].
//
// - داده‌ها از جدول `homeworks` و فقط برای حساب فعال خوانده می‌شوند؛
//   شناسهٔ حساب فعال از SharedPreferences با همان کلیدی می‌آید که
//   [LocalAuthRepository.activeAccountKey] تعریف می‌کند.
// - حذف، از نوع نرم (`is_deleted = 1`) است.
// - این فایل اسکیما را تغییر نمی‌دهد.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/domain/models/homework.dart';
import 'package:english_teacher/domain/repositories/homework_repository.dart';

/// پیاده‌سازی محلی مخزن تکالیف روی SQLite + SharedPreferences.
class LocalHomeworkRepository implements HomeworkRepository {
  /// خواندن شناسهٔ حساب فعال.
  ///
  /// در صورت نبود حساب فعال، [StateError] پرتاب می‌شود تا
  /// لایهٔ بالاتر بتواند کاربر را به ورود/ساخت حساب هدایت کند.
  Future<String> _activeAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(LocalAuthRepository.activeAccountKey);
    if (id == null || id.isEmpty) {
      throw StateError('no active account');
    }
    return id;
  }

  @override
  Future<List<Homework>> listHomeworks() async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'homeworks',
      where: 'account_id = ? AND is_deleted = 0',
      whereArgs: [accountId],
      // جدیدترین تکلیف اول
      orderBy: 'created_at DESC',
    );
    return rows.map(Homework.fromMap).toList();
  }

  @override
  Future<Homework> createHomework({
    required String title,
    required List<String> imagePaths,
    required String extractedText,
  }) async {
    final accountId = await _activeAccountId();
    final now = DateTime.now();
    final hw = Homework(
      id: const Uuid().v4(),
      accountId: accountId,
      title: title.trim().isEmpty ? 'بدون عنوان' : title.trim(),
      createdAt: now,
      updatedAt: now,
      imagePaths: imagePaths,
      extractedText: extractedText,
    );
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'homeworks',
      hw.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return hw;
  }

  @override
  Future<void> deleteHomework(String id) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'homeworks',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      // حذف فقط در محدودهٔ حساب فعال، برای جلوگیری از دست‌کاری
      // تکلیف حساب دیگر با شناسهٔ ساختگی
      where: 'id = ? AND account_id = ?',
      whereArgs: [id, accountId],
    );
  }
}
