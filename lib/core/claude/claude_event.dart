import 'dart:convert';

/// Claude Code stream-json 协议事件的抽象。
sealed class ClaudeEvent {
  const ClaudeEvent();

  factory ClaudeEvent.fromRawJson(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    return ClaudeEvent.fromJson(json);
  }

  factory ClaudeEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'system':
        return ClaudeSystemEvent(
          subtype: json['subtype'] as String?,
          sessionId: json['session_id'] as String?,
          cwd: json['cwd'] as String?,
          model: json['model'] as String?,
        );
      case 'assistant':
        return ClaudeAssistantEvent(
          messageId: json['message']?['id'] as String?,
          content: _parseContent(json['message']?['content']),
        );
      case 'user':
        return ClaudeUserEvent(
          content: _parseContent(json['message']?['content']),
        );
      case 'result':
        return ClaudeResultEvent(
          subtype: json['subtype'] as String?,
          result: json['result'] as String?,
          costUsd: (json['total_cost_usd'] as num?)?.toDouble(),
          durationMs: json['duration_ms'] as int?,
          numTurns: json['num_turns'] as int?,
          isError: json['is_error'] as bool? ?? false,
        );
      case 'stream_event':
        return ClaudeStreamEvent(inner: json['event'] as Map<String, dynamic>?);
      default:
        return ClaudeUnknownEvent(raw: json);
    }
  }

  static List<ClaudeContentBlock> _parseContent(dynamic raw) {
    if (raw is String) return [ClaudeTextBlock(text: raw)];
    if (raw is List) {
      return raw
          .map((e) => ClaudeContentBlock.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }
}

class ClaudeSystemEvent extends ClaudeEvent {
  final String? subtype;
  final String? sessionId;
  final String? cwd;
  final String? model;

  const ClaudeSystemEvent({this.subtype, this.sessionId, this.cwd, this.model});
}

class ClaudeAssistantEvent extends ClaudeEvent {
  final String? messageId;
  final List<ClaudeContentBlock> content;

  const ClaudeAssistantEvent({this.messageId, required this.content});
}

class ClaudeUserEvent extends ClaudeEvent {
  final List<ClaudeContentBlock> content;

  const ClaudeUserEvent({required this.content});
}

class ClaudeResultEvent extends ClaudeEvent {
  final String? subtype;
  final String? result;
  final double? costUsd;
  final int? durationMs;
  final int? numTurns;
  final bool isError;

  const ClaudeResultEvent({
    this.subtype,
    this.result,
    this.costUsd,
    this.durationMs,
    this.numTurns,
    this.isError = false,
  });
}

class ClaudeStreamEvent extends ClaudeEvent {
  final Map<String, dynamic>? inner;

  const ClaudeStreamEvent({this.inner});
}

class ClaudeUnknownEvent extends ClaudeEvent {
  final Map<String, dynamic> raw;

  const ClaudeUnknownEvent({required this.raw});
}

/// 助手消息内容块。
sealed class ClaudeContentBlock {
  const ClaudeContentBlock();

  factory ClaudeContentBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'text':
        return ClaudeTextBlock(text: json['text'] as String? ?? '');
      case 'thinking':
        return ClaudeThinkingBlock(text: json['thinking'] as String? ?? '');
      case 'tool_use':
        return ClaudeToolUseBlock(
          id: json['id'] as String?,
          name: json['name'] as String?,
          input: json['input'],
        );
      case 'tool_result':
        return ClaudeToolResultBlock(
          toolUseId: json['tool_use_id'] as String?,
          content: json['content'],
          isError: json['is_error'] as bool? ?? false,
        );
      default:
        return ClaudeUnknownBlock(raw: json);
    }
  }
}

class ClaudeTextBlock extends ClaudeContentBlock {
  final String text;

  const ClaudeTextBlock({required this.text});
}

class ClaudeThinkingBlock extends ClaudeContentBlock {
  final String text;

  const ClaudeThinkingBlock({required this.text});
}

class ClaudeToolUseBlock extends ClaudeContentBlock {
  final String? id;
  final String? name;
  final dynamic input;

  const ClaudeToolUseBlock({this.id, this.name, this.input});
}

class ClaudeToolResultBlock extends ClaudeContentBlock {
  final String? toolUseId;
  final dynamic content;
  final bool isError;

  const ClaudeToolResultBlock({
    this.toolUseId,
    this.content,
    this.isError = false,
  });
}

class ClaudeUnknownBlock extends ClaudeContentBlock {
  final Map<String, dynamic> raw;

  const ClaudeUnknownBlock({required this.raw});
}
