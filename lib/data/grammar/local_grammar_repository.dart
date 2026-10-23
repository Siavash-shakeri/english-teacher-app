// lib/data/grammar/local_grammar_repository.dart
//
// پیاده‌سازی محلی (SQLite) قرارداد [GrammarRepository].
//
// - داده‌ها از جدول `grammar_rules` و فقط برای حساب فعال خوانده می‌شوند؛
//   شناسهٔ حساب فعال از SharedPreferences با همان کلیدی می‌آید که
//   [LocalAuthRepository.activeAccountKey] تعریف می‌کند.
// - تشخیص تکراری‌بودن با `GrammarRule.dedupeKey` (دسته+عنوان، trim و
//   بدون حساسیت به بزرگی/کوچکی حروف) انجام می‌شود — همان الگوی
//   `LocalVocabularyRepository` ولی روی ترکیب دسته و عنوان.
// - حذف، از نوع نرم (`is_deleted = 1`) است.
// - این فایل اسکیما را تغییر نمی‌دهد.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/domain/models/grammar_rule.dart';
import 'package:english_teacher/domain/repositories/grammar_repository.dart';

/// پیاده‌سازی محلی مخزن «قواعد من» روی SQLite + SharedPreferences.
class LocalGrammarRepository implements GrammarRepository {
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
  Future<List<GrammarRule>> listRules({String? category}) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final where = StringBuffer('account_id = ? AND is_deleted = 0');
    final args = <Object?>[accountId];
    final cleanCategory = _clean(category);
    if (cleanCategory != null) {
      where.write(' AND category = ?');
      args.add(cleanCategory);
    }
    final rows = await db.query(
      'grammar_rules',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'category ASC, title ASC',
    );
    return rows.map(GrammarRule.fromMap).toList();
  }

  @override
  Future<List<String>> listCategories() async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'grammar_rules',
      columns: ['category'],
      distinct: true,
      where: 'account_id = ? AND is_deleted = 0',
      whereArgs: [accountId],
      orderBy: 'category ASC',
    );
    return rows.map((row) => (row['category'] as String?) ?? '').toList();
  }

  @override
  Future<List<GrammarRule>> searchRules(String query) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final q = '%${query.trim()}%';
    final rows = await db.query(
      'grammar_rules',
      where:
          'account_id = ? AND is_deleted = 0 AND (title LIKE ? OR category LIKE ? OR explanation LIKE ?)',
      whereArgs: [accountId, q, q, q],
      orderBy: 'category ASC, title ASC',
    );
    return rows.map(GrammarRule.fromMap).toList();
  }

  @override
  Future<GrammarRule?> getRule(String id) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'grammar_rules',
      where: 'id = ? AND account_id = ? AND is_deleted = 0',
      whereArgs: [id, accountId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GrammarRule.fromMap(rows.first);
  }

  @override
  Future<GrammarRule> upsertRule({
    required String category,
    required String title,
    required String explanation,
    String? formula,
    List<String>? examples,
    List<String>? commonMistakes,
  }) async {
    final accountId = await _activeAccountId();
    final cleanCategory = _clean(category);
    final cleanTitle = _clean(title);
    if (cleanCategory == null || cleanTitle == null) {
      throw ArgumentError('دسته و عنوان قاعده نمی‌توانند خالی باشند');
    }
    final cleanExplanation = _clean(explanation) ?? '';
    final cleanFormula = _clean(formula);
    final cleanExamples =
        (examples ?? const []).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final cleanMistakes = (commonMistakes ?? const [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    // جست‌وجوی رکورد موجود با کلید نرمال‌شده (دسته+عنوان):
    // بدون حساسیت به بزرگی/کوچکی حروف، فقط در محدودهٔ حساب فعال
    final existing = await db.query(
      'grammar_rules',
      where:
          'account_id = ? AND is_deleted = 0 AND LOWER(TRIM(category)) = ? AND LOWER(TRIM(title)) = ?',
      whereArgs: [
        accountId,
        cleanCategory.toLowerCase(),
        cleanTitle.toLowerCase(),
      ],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final current = GrammarRule.fromMap(existing.first);
      await db.update(
        'grammar_rules',
        {
          'explanation': cleanExplanation,
          'formula': cleanFormula,
          'examples': _encodeList(cleanExamples),
          'common_mistakes': _encodeList(cleanMistakes),
          'updated_at': now.millisecondsSinceEpoch,
        },
        // به‌روزرسانی فقط در محدودهٔ حساب فعال، برای جلوگیری از دست‌کاری
        // قاعدهٔ حساب دیگر با شناسهٔ ساختگی
        where: 'id = ? AND account_id = ?',
        whereArgs: [current.id, accountId],
      );
      final rows = await db.query(
        'grammar_rules',
        where: 'id = ?',
        whereArgs: [current.id],
        limit: 1,
      );
      return GrammarRule.fromMap(rows.first);
    }

    final rule = GrammarRule(
      id: const Uuid().v4(),
      accountId: accountId,
      category: cleanCategory,
      title: cleanTitle,
      explanation: cleanExplanation,
      formula: cleanFormula,
      examples: cleanExamples,
      commonMistakes: cleanMistakes,
      firstSeenAt: now,
      isStarred: false,
      updatedAt: now,
    );
    await db.insert(
      'grammar_rules',
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return rule;
  }

  @override
  Future<void> setStarred(String id, bool starred) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'grammar_rules',
      {
        'is_starred': starred ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND account_id = ?',
      whereArgs: [id, accountId],
    );
  }

  @override
  Future<void> deleteRule(String id) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'grammar_rules',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      // حذف فقط در محدودهٔ حساب فعال، برای جلوگیری از دست‌کاری
      // قاعدهٔ حساب دیگر با شناسهٔ ساختگی
      where: 'id = ? AND account_id = ?',
      whereArgs: [id, accountId],
    );
  }

  /// کدگذاری لیست رشته‌ها به JSON — دقیقاً همان قالبی که
  /// [GrammarRule.toMap] می‌نویسد و [GrammarRule.fromMap] می‌خواند.
  static String _encodeList(List<String> items) => jsonEncode(items);
}
