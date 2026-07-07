import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/claude/claude_event.dart';
import '../../core/claude/claude_process.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/project.dart';
import '../scanners/scan_result.dart';
import 'analysis_dimension.dart';
import 'analysis_prompt.dart';

class AnalysisState {
  const AnalysisState({
    this.messages = const [],
    this.running = false,
    this.error,
    this.info,
    this.dimension,
    this.hasStarted = false,
  });

  final List<ChatMessage> messages;
  final bool running;
  final String? error;
  final String? info;
  final AnalysisDimension? dimension;

  /// 是否已发送过初始分析消息
  final bool hasStarted;

  AnalysisState copyWith({
    List<ChatMessage>? messages,
    bool? running,
    String? error,
    String? info,
    AnalysisDimension? dimension,
    bool? hasStarted,
    bool clearError = false,
    bool clearInfo = false,
  }) => AnalysisState(
        messages: messages ?? this.messages,
        running: running ?? this.running,
        error: clearError ? null : (error ?? this.error),
        info: clearInfo ? null : (info ?? this.info),
        dimension: dimension ?? this.dimension,
        hasStarted: hasStarted ?? this.hasStarted,
      );
}

/// 专注于代码质量分析的 AI 会话控制器
/// 每个维度独立实例，不持久化会话（分析完即完）
class AnalysisSessionController extends StateNotifier<AnalysisState> {
  AnalysisSessionController(this._ref) : super(const AnalysisState());

  final Ref _ref;
  final _uuid = const Uuid();
  ClaudeProcess? _process;
  StreamSubscription<ClaudeEvent>? _sub;
  StreamSubscription<String>? _stderrSub;
  ChatMessage? _pendingAssistant;
  StringBuffer? _streamingText;
  Timer? _flushTimer;
  List<ChatMessage>? _pendingMessages;

  /// 会话正常结束（result 非 error）时触发的回调，用于修复完成后的状态更新。
  void Function()? _onComplete;

  /// 启动一次会话（分析或修复共用）：管理进程生命周期 + 流式展示。
  Future<void> _runSession({
    required KageProject project,
    required String prompt,
    required String info,
    AnalysisDimension? dimension,
    void Function()? onComplete,
  }) async {
    if (state.running) return;

    await _reset();
    _onComplete = onComplete;
    state = AnalysisState(
      dimension: dimension,
      running: true,
      info: info,
    );

    final exec = await _ref.read(claudeExecutableProvider.future);
    if (exec == null) {
      _onComplete = null;
      state = state.copyWith(
        error: '未检测到 claude CLI，请在设置中配置路径。',
        running: false,
        clearInfo: true,
      );
      return;
    }

    final proc = ClaudeProcess(claudeExecutable: exec);
    await proc.start(
      workingDirectory: project.path,
      bypassPermissions: true,
      model: _ref.read(activeModelProvider),
    );
    _process = proc;

    _sub = proc.events.listen(_onEvent, onError: (Object e) {
      _onComplete = null;
      state = state.copyWith(error: '$e', running: false, clearInfo: true);
    });
    _stderrSub = proc.stderr.listen((line) {
      if (line.trim().isNotEmpty) state = state.copyWith(info: '⚠ ${line.trim()}');
    });

    _addUserMessage(prompt);
    _pendingAssistant = _newAssistantMsg();
    _streamingText = StringBuffer();

    try {
      await proc.send(prompt);
      state = state.copyWith(hasStarted: true, clearInfo: true);
    } catch (e) {
      _onComplete = null;
      state = state.copyWith(error: '$e', running: false, clearInfo: true);
    }
  }

  /// 启动分析：发送维度 + 扫描上下文的初始消息
  Future<void> startAnalysis({
    required KageProject project,
    required AnalysisDimension dimension,
    ScanResult? scanResult,
  }) async {
    final prompt = AnalysisPrompt.buildInitialMessage(
      dimension: dimension,
      projectName: project.name,
      projectPath: project.path,
      scanResult: scanResult,
    );
    await _runSession(
      project: project,
      prompt: prompt,
      info: '正在启动分析会话…',
      dimension: dimension,
    );
  }

  /// 启动 AI 修复会话（复用 codeQuality 维度的侧边栏展示修复过程）。
  /// [prompt] 由调用方构造（单个或批量修复指令）；
  /// [onComplete] 在会话正常结束时触发，用于把对应 issue 标记为已修复。
  Future<void> startFix({
    required KageProject project,
    required String prompt,
    void Function()? onComplete,
  }) async {
    await _runSession(
      project: project,
      prompt: prompt,
      info: '正在启动 AI 修复…',
      dimension: AnalysisDimension.codeQuality,
      onComplete: onComplete,
    );
  }

  /// 用户追问
  Future<void> followUp(String text) async {
    if (!state.hasStarted || state.running) return;
    _addUserMessage(text);
    state = state.copyWith(running: true, clearError: true);
    _pendingAssistant = _newAssistantMsg();
    _streamingText = StringBuffer();
    try {
      await _process?.send(text);
    } catch (e) {
      state = state.copyWith(error: '$e', running: false);
    }
  }

  Future<void> interrupt() async {
    await _process?.interrupt();
    state = state.copyWith(running: false);
  }

  Future<void> reset() => _reset();

  Future<void> _reset() async {
    _cancelFlush();
    _onComplete = null;
    await _sub?.cancel();
    await _stderrSub?.cancel();
    await _process?.dispose();
    _process = null;
    _pendingAssistant = null;
    _streamingText = null;
    state = const AnalysisState();
  }

  void _addUserMessage(String text) {
    final msg = ChatMessage(
      id: _uuid.v4(),
      role: MessageRole.user,
      createdAt: DateTime.now(),
      blocks: [ClaudeTextBlock(text: text)],
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  ChatMessage _newAssistantMsg() => ChatMessage(
        id: _uuid.v4(),
        role: MessageRole.assistant,
        createdAt: DateTime.now(),
      );

  void _onEvent(ClaudeEvent event) {
    if (event is! ClaudeStreamEvent) _flushNow();
    if (state.info != null) state = state.copyWith(clearInfo: true);

    if (event is ClaudeStreamEvent) {
      _handleStream(event.inner);
    } else if (event is ClaudeAssistantEvent) {
      _handleAssistant(event);
    } else if (event is ClaudeResultEvent) {
      final ok = !event.isError;
      state = state.copyWith(
        running: false,
        error: event.isError ? event.result : null,
      );
      _pendingAssistant = null;
      _streamingText = null;
      final cb = _onComplete;
      _onComplete = null;
      if (ok) cb?.call();
    }
  }

  void _handleAssistant(ClaudeAssistantEvent event) {
    final pending = _pendingAssistant;
    if (pending != null) {
      pending.blocks
        ..clear()
        ..addAll(event.content);
      final msgs = [...state.messages];
      final idx = msgs.indexWhere((m) => m.id == pending.id);
      if (idx >= 0) { msgs[idx] = pending; } else { msgs.add(pending); }
      state = state.copyWith(messages: msgs);
    }
    _pendingAssistant = _newAssistantMsg();
    _streamingText = StringBuffer();
  }

  void _handleStream(Map<String, dynamic>? inner) {
    if (inner == null) return;
    if (inner['type'] != 'content_block_delta') return;
    final delta = inner['delta'] as Map<String, dynamic>?;
    if (delta == null) return;
    final pending = _pendingAssistant;
    final buf = _streamingText;
    if (pending == null || buf == null) return;

    final dtype = delta['type'] as String?;
    if (dtype == 'text_delta') {
      buf.write(delta['text'] as String? ?? '');
      _flushText(pending, buf);
    } else if (dtype == 'thinking_delta') {
      buf.write(delta['thinking'] as String? ?? '');
      _flushText(pending, buf, thinking: true);
    }
  }

  void _flushText(ChatMessage pending, StringBuffer buf, {bool thinking = false}) {
    final block = thinking
        ? ClaudeThinkingBlock(text: buf.toString())
        : ClaudeTextBlock(text: buf.toString());
    final base = _pendingMessages ?? state.messages;
    final msgs = [...base];
    final idx = msgs.indexWhere((m) => m.id == pending.id);
    if (idx >= 0) {
      msgs[idx].blocks..clear()..add(block);
    } else {
      pending.blocks..clear()..add(block);
      msgs.add(pending);
    }
    _pendingMessages = msgs;
    if (_flushTimer != null) return;
    _flushTimer = Timer(const Duration(milliseconds: 50), () {
      _flushTimer = null;
      final m = _pendingMessages;
      if (m != null) { _pendingMessages = null; state = state.copyWith(messages: m); }
    });
  }

  void _flushNow() {
    _flushTimer?.cancel();
    _flushTimer = null;
    final m = _pendingMessages;
    if (m != null) { _pendingMessages = null; state = state.copyWith(messages: m); }
  }

  void _cancelFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pendingMessages = null;
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

/// 每个维度独立 provider（family）
final analysisSessionProvider = StateNotifierProvider.family<
    AnalysisSessionController, AnalysisState, AnalysisDimension>(
  (ref, _) => AnalysisSessionController(ref),
);
