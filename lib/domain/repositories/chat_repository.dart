// lib/domain/repositories/chat_repository.dart
//
// قرارداد مخزن تاریخچهٔ گفت‌وگو با معلم هوش مصنوعی.

import '../models/chat_message.dart';

/// مخزن گفت‌وگوها — همیشه محدود به حساب فعال.
abstract class ChatRepository {
  /// پیام‌ها به ترتیب زمان (قدیمی → جدید).
  Future<List<ChatMessage>> listMessages({int limit = 200});

  /// افزودن پیام کاربر یا مدل.
  Future<ChatMessage> addMessage({required String role, required String content});

  /// به‌روزرسانی متن یک پیام (مثلاً تکمیل استریم).
  Future<void> updateMessage(String id, String content);

  /// پاک‌سازی کامل تاریخچهٔ حساب فعال (حذف نرم).
  Future<void> clearHistory();
}
