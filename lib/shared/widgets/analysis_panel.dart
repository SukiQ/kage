import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../core/analysis/analysis_dimension.dart';
import '../../core/analysis/analysis_session_controller.dart';
import '../../core/claude/claude_event.dart';
import '../../data/models/chat_message.dart';
import '../theme/kage_icons.dart';
import '../theme/kage_tokens.dart';
import 'kage_markdown.dart';

/// 通用 AI 分析面板（右侧滑出）——各维度模块共用
class AnalysisPanel extends ConsumerStatefulWidget {
  const AnalysisPanel({super.key, required this.dimension});
  final AnalysisDimension dimension;

  @override
  ConsumerState<AnalysisPanel> createState() => _AnalysisPanelState();
}

class _AnalysisPanelState extends ConsumerState<AnalysisPanel> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  late final FocusNode _focus;
  bool _stick = true;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(onKeyEvent: _onKey);
    _scroll.addListener(() {
      if (!_scroll.hasClients) return;
      final p = _scroll.position;
      _stick = p.pixels >= p.maxScrollExtent - 64;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    _ctrl.clear();
    _stick = true;
    await ref.read(analysisSessionProvider(widget.dimension).notifier).followUp(t);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollEnd());
  }

  void _scrollEnd() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey != LogicalKeyboardKey.enter &&
        e.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (_ctrl.value.composing.isValid) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _send();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisSessionProvider(widget.dimension));
    final cs = Theme.of(context).colorScheme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_stick && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });

    return Column(children: [
      // 标题栏
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
        child: Row(children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Text('AI 深度分析 · ${widget.dimension.label}',
              style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          if (state.running)
            IconButton(
              icon: const Icon(KageIcons.stop, size: 16),
              tooltip: '中断',
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(analysisSessionProvider(widget.dimension).notifier).interrupt(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 16),
            tooltip: '重置',
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(analysisSessionProvider(widget.dimension).notifier).reset(),
          ),
        ]),
      ),

      // 消息列表
      Expanded(
        child: state.messages.isEmpty
            ? _empty(context, cs, state)
            : SelectionArea(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: state.messages.length + (_isThinking(state) ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == state.messages.length) return const _ThinkingDots();
                    final msg = state.messages[i];
                    final live = state.running &&
                        i == state.messages.length - 1 &&
                        msg.role == MessageRole.assistant;
                    return _MsgTile(message: msg, live: live);
                  },
                ),
              ),
      ),

      // 错误提示
      if (state.error != null)
        Container(
          width: double.infinity,
          color: cs.errorContainer,
          padding: const EdgeInsets.all(8),
          child: Text(state.error!, style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
        ),

      // info 提示
      if (state.info != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Icon(KageIcons.alert, size: 12, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(child: Text(state.info!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),

      // 输入栏（仅 hasStarted 后出现）
      if (state.hasStarted) _buildInput(context, cs, state.running),
    ]);
  }

  bool _isThinking(AnalysisState state) {
    if (!state.running) return false;
    if (state.messages.isEmpty) return true;
    final last = state.messages.last;
    if (last.role != MessageRole.assistant) return true;
    return !last.blocks.any((b) =>
      (b is ClaudeTextBlock && b.text.isNotEmpty) ||
      (b is ClaudeThinkingBlock && b.text.isNotEmpty));
  }

  Widget _empty(BuildContext context, ColorScheme cs, AnalysisState state) {
    if (state.running) {
      return const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(height: 12),
          Text('AI 分析启动中…', style: TextStyle(fontSize: 13)),
        ],
      ));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_awesome_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('点击「AI 分析」开始${widget.dimension.label}深度分析',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _buildInput(BuildContext context, ColorScheme cs, bool running) {
    final tok = KageDesignTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(tok.radiusButton),
        ),
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                hintText: '追问…',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          running
            ? IconButton.outlined(
                style: IconButton.styleFrom(foregroundColor: cs.error),
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.read(analysisSessionProvider(widget.dimension).notifier).interrupt(),
                icon: const Icon(KageIcons.stop, size: 16),
              )
            : IconButton(
                style: IconButton.styleFrom(
                    backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
                visualDensity: VisualDensity.compact,
                onPressed: _send,
                icon: const Icon(KageIcons.send, size: 16),
              ),
        ]),
      ),
    );
  }
}

class _MsgTile extends StatelessWidget {
  const _MsgTile({required this.message, this.live = false});
  final ChatMessage message;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUser = message.role == MessageRole.user;
    final tok = KageDesignTokens.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tok.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < message.blocks.length; i++)
            _block(context, cs, message.blocks[i], live && i == message.blocks.length - 1),
          if (isUser) Divider(height: 1, color: cs.outlineVariant),
        ],
      ),
    );
  }

  Widget _block(BuildContext context, ColorScheme cs, ClaudeContentBlock block, bool live) {
    switch (block) {
      case ClaudeTextBlock(:final text):
        if (text.trim().isEmpty) return const SizedBox.shrink();
        return MarkdownBlock(
          data: text,
          selectable: true,
          config: kageMarkdownConfig(context),
        );
      case ClaudeThinkingBlock(:final text):
        if (text.trim().isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(text, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
        );
      case ClaudeToolUseBlock(:final name):
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.onSurface.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(KageIcons.tool, size: 12, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(name ?? '工具', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++) _dot(i, cs.onSurfaceVariant),
      ]),
    );
  }

  Widget _dot(int i, Color c) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) {
      final t = (_ctrl.value * 3 + i * 0.6) % 3;
      final v = (t < 1.0) ? sin(t * pi) : 0.0;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Opacity(
          opacity: 0.35 + 0.65 * v,
          child: Transform.translate(
            offset: Offset(0, -3 * v),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          ),
        ),
      );
    },
  );
}
