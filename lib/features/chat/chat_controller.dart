import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/claude/claude_event.dart';
import '../../core/claude/claude_process.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/project.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.running = false,
    this.sessionId,
    this.currentSessionMetaId,
    this.error,
    this.lastCost,
    this.lastDurationMs,
    this.permissionMode = 'default',
    this.info,
    this.model = 'default',
    this.actualModel,
  });

  final List<ChatMessage> messages;
  final bool running;
  final String? sessionId;
  final String? currentSessionMetaId;
  final String? error;
  final double? lastCost;
  final int? lastDurationMs;
  final String permissionMode;

  /// 运行时提示：启动中 / claude stderr 关键行。首个 claude 事件到来时清空。
  final String? info;

  /// Claude 模型别名：default / sonnet / opus / haiku。default = 不传 --model。
  final String model;

  /// 实际生效模型（来自 claude system init event，反映 cc switch 等外部切换），用于显示。
  final String? actualModel;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? running,
    String? sessionId,
    String? currentSessionMetaId,
    String? error,
    double? lastCost,
    int? lastDurationMs,
    String? permissionMode,
    String? info,
    String? model,
    String? actualModel,
    bool clearError = false,
    bool clearInfo = false,
  }) => ChatState(
    messages: messages ?? this.messages,
    running: running ?? this.running,
    sessionId: sessionId ?? this.sessionId,
    currentSessionMetaId: currentSessionMetaId ?? this.currentSessionMetaId,
    error: clearError ? null : (error ?? this.error),
    lastCost: lastCost ?? this.lastCost,
    lastDurationMs: lastDurationMs ?? this.lastDurationMs,
    permissionMode: permissionMode ?? this.permissionMode,
    info: clearInfo ? null : (info ?? this.info),
    model: model ?? this.model,
    actualModel: actualModel ?? this.actualModel,
  );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState());

  final Ref _ref;
  final _uuid = const Uuid();
  ClaudeProcess? _process;
  StreamSubscription<ClaudeEvent>? _sub;
  StreamSubscription<String>? _stderrSub;
  ChatMessage? _pendingAssistant;
  StringBuffer? _streamingText;
  String? _currentProjectId;
  bool _modeLocked = false; // 用户是否显式切换过权限模式
  // 流式 delta 节流：累积后定时 flush，避免每个 token 都重建整棵 UI。
  Timer? _flushTimer;
  List<ChatMessage>? _pendingMessages;

  // 延迟切换：运行中改模型/模式时记录，等当前回合 result 后再重启进程生效。
  KageProject? _currentProject;
  bool _pendingRestart = false;

  Future<void> send(String text, KageProject project) async {
    // 降级原生连发：不阻塞 running。pending/streaming 仅在首轮创建，
    // 避免覆盖进行中的回合（连发时第二条的回复展示可能错/丢，属已知降级）。
    _currentProject = project;
    state = state.copyWith(
      error: null,
      clearError: true,
      running: true,
      clearInfo: true,
    );

    final sessRepo = await _ref.read(sessionRepositoryProvider.future);

    if (state.currentSessionMetaId == null || _currentProjectId != project.id) {
      final meta = await sessRepo.start(
        projectId: project.id,
        title: text.length > 30 ? '${text.substring(0, 30)}…' : text,
      );
      _currentProjectId = project.id;
      state = state.copyWith(currentSessionMetaId: meta.id);
    }

    await ensureStarted(project);

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      createdAt: DateTime.now(),
      blocks: [ClaudeTextBlock(text: text)],
    );
    final msgs = [...state.messages, userMsg];
    state = state.copyWith(messages: msgs);
    await _persist(msgs);

    if (_pendingAssistant == null) {
      _pendingAssistant = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        createdAt: DateTime.now(),
      );
      _streamingText = StringBuffer();
    }

    try {
      await _process!.send(text);
    } catch (e) {
      state = state.copyWith(error: '$e', running: false, clearInfo: true);
    }
  }

  /// 从历史会话恢复，自动用 --resume 接续。
  Future<void> loadSession(ChatSessionMeta meta, KageProject project) async {
    await _sub?.cancel();
    await _stderrSub?.cancel();
    await _process?.dispose();
    _process = null;

    final sessRepo = await _ref.read(sessionRepositoryProvider.future);
    final stored = await sessRepo.loadMessages(meta.id);
    final msgs = stored
        .map(
          (s) => ChatMessage(
            id: s.id,
            role: switch (s.role) {
              'user' => MessageRole.user,
              'assistant' => MessageRole.assistant,
              _ => MessageRole.system,
            },
            createdAt: s.createdAt,
            blocks: [ClaudeTextBlock(text: s.text)],
          ),
        )
        .toList();

    state = ChatState(
      messages: msgs,
      currentSessionMetaId: meta.id,
      sessionId: meta.claudeSessionId,
      permissionMode: _modeLocked
          ? state.permissionMode
          : project.permissionMode,
    );
    _currentProjectId = project.id;
    _currentProject = project;

    if (meta.claudeSessionId != null) {
      await ensureStarted(project, resumeSessionId: meta.claudeSessionId);
    }
  }

  Future<void> startNewSession() async {
    await _sub?.cancel();
    await _stderrSub?.cancel();
    await _process?.dispose();
    _process = null;
    _pendingAssistant = null;
    _streamingText = null;
    _cancelFlush();
    _currentProjectId = null;
    state = const ChatState();
  }

  Future<void> ensureStarted(
    KageProject project, {
    String? resumeSessionId,
  }) async {
    if (_process != null) return;
    final exec = await _ref.watch(claudeExecutableProvider.future);
    if (exec == null) {
      state = state.copyWith(error: '未检测到 claude CLI，请先安装或在设置中配置路径。');
      return;
    }

    final proc = ClaudeProcess(claudeExecutable: exec);
    await proc.start(
      workingDirectory: project.path,
      resumeSessionId: resumeSessionId,
      permissionMode: state.permissionMode,
      model: state.model,
    );
    _process = proc;

    _sub = proc.events.listen(
      _onEvent,
      onError: (Object e) {
        state = state.copyWith(error: '$e', running: false, clearInfo: true);
      },
    );
    _stderrSub = proc.stderr.listen((line) {
      // 透传 claude stderr 关键行到 UI，让卡住时能看到原因
      final trimmed = line.trim();
      if (trimmed.isEmpty) return;
      state = state.copyWith(info: '⚠ $trimmed');
    });
  }

  Future<void> interrupt() async {
    await _process?.interrupt();
    state = state.copyWith(running: false);
  }

  /// 设置运行时提示（如"正在拉取 SonarQube 报告…"）；首个 claude 事件到来时会清空。
  Future<void> setInfo(String info) async {
    state = state.copyWith(info: info);
  }

  /// 切换权限模式：运行中切换不中断当前回合，等 result 后重启生效；
  /// 空闲时立即重启。--resume 续接会话。
  Future<void> setPermissionMode(String mode, KageProject project) async {
    if (mode == state.permissionMode) return;
    _modeLocked = true;
    _currentProject = project;
    state = state.copyWith(permissionMode: mode, clearInfo: true);
    if (state.running) {
      _pendingRestart = true;
      state = state.copyWith(info: '权限模式将在当前回合后生效');
      return;
    }
    await _restartWith(project);
  }

  /// 切换 Claude 模型：运行中切换不中断当前回合，等 result 后重启生效；
  /// 空闲时立即重启。--resume 续接。
  Future<void> setModel(String model, KageProject project) async {
    if (model == state.model) return;
    _currentProject = project;
    // resume 会话的模型由 transcript 决定，--model 会被忽略（claude 官方行为）；
    // 改用会话内 /model 命令切换，并乐观更新徽标（actualModel）。
    state = state.copyWith(model: model, actualModel: model, clearInfo: true);
    final proc = _process;
    if (proc != null && proc.isRunning) {
      await proc.send('/model $model');
      state = state.copyWith(info: '模型已切换为 $model');
    }
    // 进程未运行：下次 ensureStarted 用 --model（新会话 --model 生效）
  }

  /// dispose 旧进程并以当前 state 的 model/permissionMode + --resume 重启。
  Future<void> _restartWith(KageProject project) async {
    await _sub?.cancel();
    await _stderrSub?.cancel();
    await _process?.dispose();
    _process = null;
    _pendingAssistant = null;
    _streamingText = null;
    _cancelFlush();
    if (state.sessionId != null) {
      try {
        await ensureStarted(project, resumeSessionId: state.sessionId);
      } catch (_) {
        await ensureStarted(project); // resume 失败则退化为新进程
      }
    }
  }

  Future<void> reset() async {
    await _sub?.cancel();
    await _stderrSub?.cancel();
    await _process?.dispose();
    _process = null;
    _pendingAssistant = null;
    _streamingText = null;
    _cancelFlush();
    _modeLocked = false;
    state = const ChatState();
  }

  Future<void> _onEvent(ClaudeEvent event) async {
    // 非 delta 事件前，先 flush 节流中暂存的流式文本
    if (event is! ClaudeStreamEvent) _flushNow();
    // 首个事件 = claude 已响应，清掉启动中/stderr 提示
    if (state.info != null) {
      state = state.copyWith(clearInfo: true);
    }
    if (event is ClaudeSystemEvent) {
      if (event.sessionId != null) {
        state = state.copyWith(sessionId: event.sessionId);
        _syncMeta(claudeSessionId: event.sessionId);
      }
      if (event.model != null) {
        state = state.copyWith(actualModel: event.model);
      }
      return;
    }
    if (event is ClaudeStreamEvent) {
      _handleStreamEvent(event.inner);
      return;
    }
    if (event is ClaudeAssistantEvent) {
      _handleAssistant(event);
      return;
    }
    if (event is ClaudeUserEvent) {
      final msg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.system,
        createdAt: DateTime.now(),
        blocks: event.content,
      );
      final msgs = [...state.messages, msg];
      state = state.copyWith(messages: msgs);
      _persist(msgs);
      return;
    }
    if (event is ClaudeResultEvent) {
      state = state.copyWith(
        running: false,
        error: event.isError ? event.result : null,
        lastCost: event.costUsd,
        lastDurationMs: event.durationMs,
      );
      _pendingAssistant = null;
      _streamingText = null;
      // 运行中切换的模型/模式：当前回合已结束，现在重启进程使其生效。
      if (_pendingRestart) {
        _pendingRestart = false;
        final p = _currentProject;
        if (p != null) {
          await _restartWith(p);
        }
      }
      return;
    }
  }

  void _handleAssistant(ClaudeAssistantEvent event) {
    final pending = _pendingAssistant;
    if (pending != null) {
      pending
        ..blocks.clear()
        ..blocks.addAll(event.content);
      final messages = [...state.messages];
      final idx = messages.indexWhere((m) => m.id == pending.id);
      if (idx >= 0) {
        messages[idx] = pending;
      } else {
        messages.add(pending);
      }
      state = state.copyWith(messages: messages);
      _persist(messages);
    } else {
      final msg = ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        createdAt: DateTime.now(),
        blocks: event.content,
      );
      final msgs = [...state.messages, msg];
      state = state.copyWith(messages: msgs);
      _persist(msgs);
    }
    _pendingAssistant = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.assistant,
      createdAt: DateTime.now(),
    );
    _streamingText = StringBuffer();
  }

  void _handleStreamEvent(Map<String, dynamic>? inner) {
    if (inner == null) return;
    final type = inner['type'] as String?;
    if (type != 'content_block_delta') return;
    final delta = inner['delta'] as Map<String, dynamic>?;
    if (delta == null) return;
    final deltaType = delta['type'] as String?;
    final pending = _pendingAssistant;
    final buf = _streamingText;
    if (pending == null || buf == null) return;

    if (deltaType == 'text_delta') {
      buf.write(delta['text'] as String? ?? '');
      _flushStreamingText(pending, buf);
    } else if (deltaType == 'thinking_delta') {
      buf.write(delta['thinking'] as String? ?? '');
      _flushStreamingText(pending, buf, isThinking: true);
    }
  }

  void _flushStreamingText(
    ChatMessage pending,
    StringBuffer buf, {
    bool isThinking = false,
  }) {
    final block = isThinking
        ? ClaudeThinkingBlock(text: buf.toString())
        : ClaudeTextBlock(text: buf.toString());
    final base = _pendingMessages ?? state.messages;
    final messages = [...base];
    final idx = messages.indexWhere((m) => m.id == pending.id);
    if (idx >= 0) {
      messages[idx].blocks.clear();
      messages[idx].blocks.add(block);
    } else {
      pending.blocks.clear();
      pending.blocks.add(block);
      messages.add(pending);
    }
    _pendingMessages = messages;
    _scheduleFlush();
  }

  /// 定时 flush：每 50ms 至多更新一次 state，避免高频 delta 卡 UI。
  void _scheduleFlush() {
    if (_flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 50), () {
      _flushTimer = null;
      final m = _pendingMessages;
      if (m != null) {
        _pendingMessages = null;
        state = state.copyWith(messages: m);
      }
    });
  }

  /// 立即 flush 节流中暂存的流式文本（非 delta 事件前调用，保证 state 最新）。
  void _flushNow() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final m = _pendingMessages;
    if (m != null) {
      _pendingMessages = null;
      state = state.copyWith(messages: m);
    }
  }

  /// 丢弃节流暂存（重置/切换进程时调用，防止残留 flush 覆盖新 state）。
  void _cancelFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingMessages = null;
  }

  Future<void> _persist(List<ChatMessage> msgs) async {
    final metaId = state.currentSessionMetaId;
    if (metaId == null) return;
    final sessRepo = await _ref.read(sessionRepositoryProvider.future);
    final stored = msgs.map(StoredMessage.fromChatMessage).toList();
    await sessRepo.saveMessages(metaId, stored);
  }

  Future<void> _syncMeta({String? claudeSessionId, String? title}) async {
    final metaId = state.currentSessionMetaId;
    if (metaId == null) return;
    final sessRepo = await _ref.read(sessionRepositoryProvider.future);
    final all = sessRepo.all();
    final i = all.indexWhere((m) => m.id == metaId);
    if (i < 0) return;
    var meta = all[i];
    if (claudeSessionId != null && meta.claudeSessionId == null) {
      meta = meta.copyWith(claudeSessionId: claudeSessionId);
    }
    if (title != null && meta.title == '新会话') {
      meta = meta.copyWith(title: title);
    }
    await sessRepo.updateMeta(meta);
  }

  @override
  void dispose() {
    _cancelFlush();
    _sub?.cancel();
    _stderrSub?.cancel();
    _process?.dispose();
    super.dispose();
  }
}

final chatControllerProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) {
    return ChatController(ref);
  },
);

/// 工具方法：把 content blocks 简洁地序列化为可显示文本。
String summarizeBlocks(Iterable<ClaudeContentBlock> blocks) {
  final buf = StringBuffer();
  for (final b in blocks) {
    switch (b) {
      case ClaudeTextBlock(:final text):
        buf.writeln(text);
      case ClaudeThinkingBlock(:final text):
        buf.writeln('[思考] $text');
      case ClaudeToolUseBlock(:final name, :final input):
        buf.writeln('[工具调用] $name(${jsonEncode(input)})');
      case ClaudeToolResultBlock(:final content, :final isError):
        final text = content is String ? content : jsonEncode(content);
        buf.writeln('[工具结果${isError ? "/错误" : ""}] $text');
      case ClaudeUnknownBlock(:final raw):
        buf.writeln('[未知块] ${jsonEncode(raw)}');
    }
  }
  return buf.toString().trim();
}
