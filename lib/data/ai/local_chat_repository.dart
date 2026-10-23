// lib/data/ai/local_chat_repository.dart
//
// پیاده‌سازی محلی (SQLite) قرارداد [ChatRepository].
//
// - داده‌ها از جدول `chat_messages` و فقط برای حساب فعال؛
//   شناسهٔ حساب فعال از SharedPreferences با کلید
//   [LocalAuthRepository.activeAccountKey].
// - حذف، نرم (`is_deleted = 1`) است.
// - این فایل اسکیما را تغییر نمی‌دهد.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'package:english_teacher/data/auth/local_auth_repository.dart';
import 'package:english_teacher/data/local/database_helper.dart';
import 'package:english_teacher/domain/models/chat_message.dart';
import 'package:english_teacher/domain/repositories/chat_repository.dart';

/// پیاده‌سازی محلی مخزن گفت‌وگو روی SQLite.
class LocalChatRepository implements ChatRepository {
  final _uuid = const Uuid();

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
  Future<List<ChatMessage>> listMessages({int limit = 200}) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'chat_messages',
      where: 'account_id = ? AND is_deleted = 0',
      whereArgs: [accountId],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(ChatMessage.fromMap).toList();
  }

  @override
  Future<ChatMessage> addMessage({
    required String role,
    required String content,
  }) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final message = ChatMessage(
      id: _uuid.v4(),
      accountId: accountId,
      role: role,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert(
      'chat_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return message;
  }

  @override
  Future<void> updateMessage(String id, String content) async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'chat_messages',
      {
        'content': content,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ? AND account_id = ? AND is_deleted = 0',
      whereArgs: [id, accountId],
    );
  }

  @override
  Future<void> clearHistory() async {
    final accountId = await _activeAccountId();
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'chat_messages',
      {'is_deleted': 1},
      where: 'account_id = ? AND is_deleted = 0',
      whereArgs: [accountId],
    );
  }
}
