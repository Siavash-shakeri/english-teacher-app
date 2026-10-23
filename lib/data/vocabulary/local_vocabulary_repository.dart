// lib/data/vocabulary/local_vocabulary_repository.dart
//
// پیاده‌سازی محلی (SQLite) قرارداد [VocabularyRepository].
//
// - داده‌ها از جدول `words` و فقط برای حساب فعال خوانده می‌شوند؛
//   شناسهٔ حساب فعال از SharedPreferences با همان کلیدی می‌آید که
//   [LocalAuthRepository.activeAccountKey] تعریف می‌کند.
// - مقایسهٔ تکراری‌بودن کلمه نسبت به بزرگی/کوچکی حروف حساس نیست:
//   کلمه با trim() + toLowerCase() نرمال می‌شود.
// - حذف، از نوع نرم (`is_deleted = 1`) است.
// - این فایل اسکیما را تغییر نمی‌دهد.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/domain/models/word.dart';
import 'package:english_teacher/domain/repositories/vocabulary_repository.dart';

/// پیاده‌سازی محلی مخزن واژگان روی SQLite + SharedPreferences.
class LocalVocabularyRepository implements VocabularyRepository {
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

  /// فاصله‌های اضافی را پاک می‌کند و رشتهٔ خالی را تهی برمی‌گرداند.
  String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  Future<List<Word>> listWords() async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'words',
      where: 'account_id = ? AND is_deleted = 0',
      whereArgs: [accountId],
      // جدیدترین کلمه اول
      orderBy: 'created_at DESC',
    );
    return rows.map(Word.fromMap).toList();
  }

  @override
  Future<Word> upsertWord({
    required String word,
    required String meaning,
    String? example,
    String? source,
  }) async {
    final accountId = await _activeAccountId();
    final trimmedWord = word.trim();
    if (trimmedWord.isEmpty) {
      throw ArgumentError('کلمه نمی‌تواند خالی باشد');
    }
    final cleanMeaning = _clean(meaning) ?? '';
    final cleanExample = _clean(example);
    final cleanSource = _clean(source);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    // جست‌وجوی رکورد موجود: بدون حساسیت به بزرگی/کوچکی حروف،
    // فقط در محدودهٔ حساب فعال و کلمات حذف‌نشده
    final existing = await db.query(
      'words',
      where: 'account_id = ? AND is_deleted = 0 AND LOWER(word) = ?',
      whereArgs: [accountId, trimmedWord.toLowerCase()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final current = Word.fromMap(existing.first);
      await db.update(
        'words',
        {
          'meaning': cleanMeaning,
          // example و source فقط وقتی به‌روز می‌شوند که مقدار تازه‌ای داده شده باشد
          if (cleanExample != null) 'example': cleanExample,
          if (cleanSource != null) 'source': cleanSource,
          'updated_at': now.millisecondsSinceEpoch,
        },
        // به‌روزرسانی فقط در محدودهٔ حساب فعال، برای جلوگیری از دست‌کاری
        // کلمهٔ حساب دیگر با شناسهٔ ساختگی
        where: 'id = ? AND account_id = ?',
        whereArgs: [current.id, accountId],
      );
      final rows = await db.query(
        'words',
        where: 'id = ?',
        whereArgs: [current.id],
        limit: 1,
      );
      return Word.fromMap(rows.first);
    }

    final newWord = Word(
      id: const Uuid().v4(),
      accountId: accountId,
      word: trimmedWord,
      meaning: cleanMeaning,
      // pronunciation و pos فعلاً تهی‌اند و در مرحلهٔ ۵ پر می‌شوند؛
      // هرگز مقدار ساختگی قرار نمی‌گیرد
      example: cleanExample,
      source: cleanSource,
      nextReviewAt: now,
      intervalDays: 1,
      ease: 2.5,
      repetitions: 0,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(
      'words',
      newWord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return newWord;
  }

  @override
  Future<void> deleteWord(String id) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'words',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      // حذف فقط در محدودهٔ حساب فعال، برای جلوگیری از دست‌کاری
      // کلمهٔ حساب دیگر با شناسهٔ ساختگی
      where: 'id = ? AND account_id = ?',
      whereArgs: [id, accountId],
    );
  }
}
