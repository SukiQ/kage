import '../../core/claude/claude_event.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    List<ClaudeContentBlock> blocks = const [],
    this.error,
  }) : blocks = List<ClaudeContentBlock>.from(blocks);

  final String id;
  final MessageRole role;
  final DateTime createdAt;
  final List<ClaudeContentBlock> blocks;
  String? error;

  bool get isAssistant => role == MessageRole.assistant;

  bool get isError => error != null;

  String get plainText =>
      blocks.whereType<ClaudeTextBlock>().map((b) => b.text).join();
}

enum MessageRole { user, assistant, system }
