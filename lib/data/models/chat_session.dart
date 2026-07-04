import 'chat_message.dart';

class ChatSessionMeta {
  ChatSessionMeta({
    required this.id,
    required this.projectId,
    required this.claudeSessionId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String? claudeSessionId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'claudeSessionId': claudeSessionId,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ChatSessionMeta.fromJson(Map<String, dynamic> json) =>
      ChatSessionMeta(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        claudeSessionId: json['claudeSessionId'] as String?,
        title: json['title'] as String? ?? '新会话',
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  ChatSessionMeta copyWith({
    String? claudeSessionId,
    String? title,
    DateTime? updatedAt,
  }) => ChatSessionMeta(
    id: id,
    projectId: projectId,
    claudeSessionId: claudeSessionId ?? this.claudeSessionId,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// 单条消息的持久化形式。
class StoredMessage {
  const StoredMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    required this.text,
  });

  final String id;
  final String role; // user / assistant / system
  final DateTime createdAt;
  final String text;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'createdAt': createdAt.toIso8601String(),
    'text': text,
  };

  factory StoredMessage.fromJson(Map<String, dynamic> json) => StoredMessage(
    id: json['id'] as String,
    role: json['role'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    text: json['text'] as String? ?? '',
  );

  factory StoredMessage.fromChatMessage(ChatMessage m) {
    final role = switch (m.role) {
      MessageRole.user => 'user',
      MessageRole.assistant => 'assistant',
      MessageRole.system => 'system',
    };
    return StoredMessage(
      id: m.id,
      role: role,
      createdAt: m.createdAt,
      text: m.plainText,
    );
  }
}
