// lib/domain/models/chat_message.dart
//
// مدل پیام گفت‌وگو با معلم هوش مصنوعی — منطبق بر جدول chat_messages:
// id, account_id, role ('user' | 'model'), content, created_at,
// updated_at, is_deleted.

/// یک پیام در گفت‌وگو با معلم هوش مصنوعی.
class ChatMessage {
  final String id;
  final String accountId;
  final String role; // 'user' یا 'model'
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatMessage({
    required this.id,
    required this.accountId,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUser => role == 'user';

  ChatMessage copyWith({String? content, DateTime? updatedAt}) => ChatMessage(
        id: id,
        accountId: accountId,
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  factory ChatMessage.fromMap(Map<String, Object?> map) => ChatMessage(
        id: map['id'] as String,
        accountId: map['account_id'] as String,
        role: map['role'] as String,
        content: map['content'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );

  /// `is_deleted` همیشه ۰ (زنده) نوشته می‌شود؛ حذف نرم از طریق مخزن.
  Map<String, Object?> toMap() => {
        'id': id,
        'account_id': accountId,
        'role': role,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'is_deleted': 0,
      };

  @override
  String toString() => 'ChatMessage(id: $id, role: $role)';
}
