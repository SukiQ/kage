import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/claude/claude_event.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/project.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/theme/kage_tokens.dart';
import '../../shared/widgets/kage_markdown.dart';
import '../projects/projects_dialog.dart';
import 'chat_controller.dart';

class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.project});

  final KageProject project;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late final FocusNode _focusNode;
  final List<String> _attachments = [];
  bool _stick = true; // 粘底跟随；用户上滚浏览时暂停

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _onKeyEvent);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    _stick = pos.pixels >= pos.maxScrollExtent - 64;
  }

  /// 粘底时跟随到最底；用户上滚浏览时不拉回，避免拖动跳动。
  void _maybeStickToBottom() {
    if (!_scrollController.hasClients || !_stick) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    final buf = StringBuffer(text);
    for (final path in _attachments) {
      buf.writeln();
      buf.write('@${path.replaceAll(r'\', '/')}');
    }
    _controller.clear();
    setState(_attachments.clear);
    await ref
        .read(chatControllerProvider.notifier)
        .send(buf.toString(), widget.project);
    _stick = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    setState(() {
      _attachments.addAll(result.paths.whereType<String>());
    });
  }

  void _cycleMode() {
    const modes = ['default', 'plan', 'acceptEdits', 'bypassPermissions'];
    final cur = ref.read(chatControllerProvider).permissionMode;
    final idx = modes.indexOf(cur).clamp(0, modes.length - 1);
    final next = modes[(idx + 1) % modes.length];
    ref
        .read(chatControllerProvider.notifier)
        .setPermissionMode(next, widget.project);
  }

  void _cycleModel() {
    const models = ['default', 'sonnet', 'opus', 'haiku'];
    final cur = ref.read(chatControllerProvider).model;
    final idx = models.indexOf(cur).clamp(0, models.length - 1);
    final next = models[(idx + 1) % models.length];
    ref.read(chatControllerProvider.notifier).setModel(next, widget.project);
  }

  /// 当前权限模式对应的强调色（提交按钮背景）。
  Color _modeColor(String mode) => switch (mode) {
    'plan' => const Color(0xFF3E7CB1),
    'acceptEdits' => const Color(0xFF2DBEA6),
    'bypassPermissions' => const Color(0xFFD94F4F),
    _ => Theme.of(context).colorScheme.primary,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final thinking = _isThinking(state);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStickToBottom());

    return Column(
      children: [
        Expanded(
          child: _buildMessageList(state.messages, thinking, state.running),
        ),
        if (state.error != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(8),
            child: Text(
              state.error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        _buildInfo(state),
        _buildComposer(
          state.running,
          state.permissionMode,
          state.actualModel ?? state.model,
        ),
      ],
    );
  }

  /// 是否处于"思考中"：Claude 正在运行，且最后一条 assistant 消息还没产出可见文本。
  bool _isThinking(ChatState state) {
    if (!state.running) return false;
    final msgs = state.messages;
    if (msgs.isEmpty) return true;
    final last = msgs.last;
    if (last.role != MessageRole.assistant) return true;
    return !last.blocks.any((b) {
      if (b is ClaudeTextBlock) return b.text.isNotEmpty;
      if (b is ClaudeThinkingBlock) return b.text.isNotEmpty;
      return false;
    });
  }

  Widget _buildMessageList(
    List<ChatMessage> messages,
    bool thinking,
    bool running,
  ) {
    if (messages.isEmpty && !thinking) {
      return const Center(child: Text('选择侧栏操作或直接发送消息开始对话'));
    }
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: messages.length + (thinking ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == messages.length) return const _ThinkingIndicator();
          final msg = messages[i];
          final isLive =
              running &&
              i == messages.length - 1 &&
              msg.role == MessageRole.assistant;
          return _MessageTile(message: msg, live: isLive);
        },
      ),
    );
  }

  Widget _buildComposer(bool running, String mode, String model) {
    final cs = Theme.of(context).colorScheme;
    final tok = KageDesignTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 框外左上角：项目选择器
            _buildProjectPicker(),
            const SizedBox(height: 8),
            // 矩形输入框：上部分输入，下部分按钮
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outline, width: 1.5),
                borderRadius: BorderRadius.circular(tok.radiusButton),
              ),
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
              child: Column(
                children: [
                  // 附件区
                  if (_attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _attachments
                            .asMap()
                            .entries
                            .map(
                              (e) => Chip(
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  p.basename(e.value),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                deleteIcon: const Icon(
                                  KageIcons.delete,
                                  size: 14,
                                ),
                                onDeleted: () => setState(
                                  () => _attachments.removeAt(e.key),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  // 上部分：输入区
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: _buildTextField(),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 下部分：按钮栏
                  Row(
                    children: [
                      // 左下角：添加 + 模型
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        icon: const Icon(KageIcons.paperclip),
                        tooltip: '添加文件',
                        onPressed: _pickFile,
                      ),
                      _ModelBadge(model: model, onTap: _cycleModel),
                      const Spacer(),
                      // 右下角：模式 + 提交
                      _ModeBadge(mode: mode, onTap: _cycleMode),
                      const SizedBox(width: 6),
                      if (running)
                        IconButton.outlined(
                          style: IconButton.styleFrom(
                            foregroundColor: cs.error,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ref
                              .read(chatControllerProvider.notifier)
                              .interrupt(),
                          icon: const Icon(KageIcons.stop, size: 18),
                          tooltip: '中断',
                        )
                      else
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: _modeColor(mode),
                            foregroundColor: Colors.white,
                          ),
                          visualDensity: VisualDensity.compact,
                          onPressed: _send,
                          icon: const Icon(KageIcons.send, size: 18),
                          tooltip: '发送',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 框外左上角的项目选择器：切换/管理项目。
  Widget _buildProjectPicker() {
    final projects =
        ref.watch(projectRepositoryProvider).valueOrNull?.all ?? const [];
    return PopupMenuButton<String>(
      tooltip: '选择项目',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(KageIcons.folder, size: 16),
          const SizedBox(width: 6),
          Text(
            widget.project.name,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Icon(KageIcons.dropdown, size: 14),
        ],
      ),
      itemBuilder: (_) => [
        ...projects.map((p) => PopupMenuItem(value: p.id, child: Text(p.name))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '__manage__', child: Text('管理项目…')),
      ],
      onSelected: (value) {
        if (value == '__manage__') {
          showDialog(context: context, builder: (_) => const ProjectsDialog());
          return;
        }
        final p = projects.firstWhere((e) => e.id == value);
        ref.read(activeProjectProvider.notifier).state = p;
        ref
            .read(settingsServiceProvider.future)
            .then((s) => s.setActiveProjectId(p.id));
      },
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // IME 合成中（候选框选词）放行，避免误发
    if (_controller.value.composing.isValid) {
      return KeyEventResult.ignored;
    }
    // Shift+Enter 放行换行
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _send();
    return KeyEventResult.handled;
  }

  Widget _buildTextField() {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: 8,
      textInputAction: TextInputAction.newline,
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        hintText: '输入消息，Enter 发送，Shift+Enter 换行',
      ),
    );
  }

  /// 运行时提示：claude stderr 关键行 / 延迟切换提示，显示在输入框上方。
  Widget _buildInfo(ChatState state) {
    final info = state.info;
    if (info == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isWarn = info.startsWith('⚠');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(
            isWarn ? KageIcons.alert : KageIcons.tool,
            size: 12,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              info,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// 权限模式徽标：扁平空心线条风格，点击循环切换。
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode, required this.onTap});

  final String mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = _modeInfo(mode);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info.icon, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              info.label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  ({IconData icon, String label}) _modeInfo(String mode) {
    switch (mode) {
      case 'plan':
        return (icon: KageIcons.modePlan, label: '计划模式');
      case 'acceptEdits':
        return (icon: KageIcons.modeAccept, label: '直接改模式');
      case 'bypassPermissions':
        return (icon: KageIcons.modeBypass, label: '放行模式');
      default:
        return (icon: KageIcons.modeDefault, label: '默认模式');
    }
  }
}

/// 模型徽标：与模式徽标同风格，点击循环切换 default/Sonnet/Opus/Haiku。
class _ModelBadge extends StatelessWidget {
  const _ModelBadge({required this.model, required this.onTap});

  final String model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(KageIcons.model, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              _label(model),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String m) {
    final s = m.toLowerCase();
    if (s.contains('sonnet')) return 'Sonnet 5';
    if (s.contains('opus')) return 'Opus 4.8';
    if (s.contains('haiku')) return 'Haiku 4.5';
    if (s == 'default' || m.isEmpty) return '默认';
    return m;
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, this.live = false});

  final ChatMessage message;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tok = KageDesignTokens.of(context);
    final isUser = message.role == MessageRole.user;
    final fg = cs.onSurface;
    final children = <Widget>[];
    for (var i = 0; i < message.blocks.length; i++) {
      final isLast = i == message.blocks.length - 1;
      children.add(
        _renderBlock(context, message.blocks[i], isUser, fg, live && isLast),
      );
    }
    final blocks = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tok.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          blocks,
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Divider(height: 1, color: cs.outline),
            ),
        ],
      ),
    );
  }

  Widget _renderBlock(
    BuildContext context,
    ClaudeContentBlock block,
    bool isUser,
    Color fg,
    bool live,
  ) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    switch (block) {
      case ClaudeTextBlock(:final text):
        if (text.trim().isEmpty) return const SizedBox.shrink();
        return DefaultTextStyle.merge(
          style: TextStyle(color: fg),
          child: MarkdownBlock(
            data: _linkifyPaths(text),
            selectable: true,
            config: kageMarkdownConfig(
              context,
              onLinkTap: (url) => _openPath(url),
            ),
          ),
        );
      case ClaudeThinkingBlock(:final text):
        return _ThinkingBlock(text: text, fg: fg, live: live);
      case ClaudeToolUseBlock(:final name, :final input):
        final (action, detail) = _toolInfo(name ?? '', input);
        return _ToolLine(icon: KageIcons.tool, action: action, detail: detail);
      case ClaudeToolResultBlock(:final content, :final isError):
        final text = content is String ? content : content.toString();
        final short = text.length > 120 ? '${text.substring(0, 120)}…' : text;
        return _ToolLine(
          icon: isError ? KageIcons.alert : KageIcons.check,
          color: isError ? cs.error : null,
          action: isError ? '出错' : '结果',
          detail: short,
        );
      case ClaudeUnknownBlock():
        return const SizedBox.shrink();
    }
  }
}

/// 工具调用/结果单行展示：图标 + 中文动作 + 详情（路径/命令/摘要）。
class _ToolLine extends StatelessWidget {
  const _ToolLine({
    required this.icon,
    required this.action,
    required this.detail,
    this.color,
  });

  final IconData icon;
  final String action;
  final String detail;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tok = KageDesignTokens.of(context);
    final fg = color ?? cs.onSurfaceVariant;
    final hasDetail = detail.isNotEmpty;
    return Container(
      margin: EdgeInsets.symmetric(vertical: tok.space1),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(tok.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            action,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
          if (hasDetail) ...[
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => _openPath(detail),
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color:
                        _looksLikePath(detail) ? cs.primary : cs.onSurfaceVariant,
                    decoration:
                        _looksLikePath(detail) ? TextDecoration.underline : null,
                    decorationColor: cs.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// claude 工具名 → 中文动作 + 关键参数（Read→读取 文件路径 等）。
(String, String) _toolInfo(String name, dynamic input) {
  final m = input is Map<String, dynamic> ? input : <String, dynamic>{};
  String? p(String k) => m[k]?.toString();

  switch (name) {
    case 'Read':
      return ('读取', p('file_path') ?? '');
    case 'Write':
      return ('写入', p('file_path') ?? '');
    case 'Edit':
      return ('编辑', p('file_path') ?? '');
    case 'MultiEdit':
      return ('批量编辑', p('file_path') ?? '');
    case 'NotebookEdit':
      return ('编辑笔记本', p('notebook_path') ?? '');
    case 'Bash':
      return ('执行命令', p('command') ?? '');
    case 'Glob':
      return ('查找文件', p('pattern') ?? '');
    case 'Grep':
      return ('搜索内容', p('pattern') ?? '');
    case 'LS':
    case 'List':
      return ('列出目录', p('path') ?? p('directory') ?? '');
    case 'TodoWrite':
      return ('更新待办', '');
    case 'Task':
      return ('委派子任务', p('description') ?? '');
    case 'WebSearch':
      return ('联网搜索', p('query') ?? '');
    case 'WebFetch':
      return ('抓取网页', p('url') ?? p('prompt') ?? '');
    case 'SlashCommand':
    case 'run':
      return ('运行命令', p('command') ?? p('name') ?? '');
    default:
      return (name.isEmpty ? '工具' : name, input?.toString() ?? '');
  }
}

bool _looksLikePath(String s) => RegExp(r'^[A-Za-z]:\\').hasMatch(s);

/// 把文本里的 Windows 文件路径转成 markdown 链接，便于点击打开。
/// 仅匹配「盘符:\段(\段)*」，段为单词/点/连字符，避免吞入括号/中文/标点。
/// href 用正斜杠、text 用反引号，规避 `\` 在 markdown 中被转义。
String _linkifyPaths(String text) {
  final re = RegExp(r'[A-Za-z]:\\(?:[\w.\-]+\\)*[\w.\-]+');
  return text.replaceAllMapped(re, (m) {
    final path = m[0]!;
    final href = path.replaceAll('\\', '/');
    return '[`$path`]($href)';
  });
}

/// 用系统资源管理器打开/选中给定路径（文件 → 选中，目录 → 打开）。
Future<void> _openPath(String raw) async {
  try {
    final path = raw.replaceAll('/', r'\');
    if (Platform.isWindows) {
      if (await File(path).exists()) {
        await Process.run('explorer.exe', ['/select,$path']);
      } else if (await Directory(path).exists()) {
        await Process.run('explorer.exe', [path]);
      }
    }
  } catch (_) {}
}

/// 思考过程：
/// - [live] 思考进行中：跳动三点（省略号），点击可展开查看当前实时进度；
/// - 思考完成：固定 chevron 展开图标，点击展开查看完整思考。
/// 展开后内容按段落分段渲染。
class _ThinkingBlock extends StatefulWidget {
  const _ThinkingBlock({
    required this.text,
    required this.fg,
    this.live = false,
  });

  final String text;
  final Color fg;
  final bool live;

  @override
  State<_ThinkingBlock> createState() => _ThinkingBlockState();
}

class _ThinkingBlockState extends State<_ThinkingBlock>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.live) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _ThinkingBlock old) {
    super.didUpdateWidget(old);
    if (widget.live && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.live && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.live
              ? null
              : () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: widget.live
                ? SizedBox(
                    width: 30,
                    height: 16,
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          _dot(i, cs.onSurfaceVariant),
                      ],
                    ),
                  )
                : Icon(
                    _expanded ? KageIcons.dropdown : KageIcons.chevronRight,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
          ),
        ),
        if (!widget.live && _expanded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: widget.live
                ? SelectableText(
                    widget.text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: widget.fg),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _segments(),
                  ),
          ),
      ],
    );
  }

  /// 三点错峰跳动。
  Widget _dot(int i, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = (_ctrl.value * 3 + i * 0.6) % 3;
          final v = (t < 1.0) ? sin(t * pi) : 0.0;
          return Opacity(
            opacity: 0.35 + 0.65 * v,
            child: Transform.translate(
              offset: Offset(0, -2 * v),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 思考文本按空行分段，每段独立渲染、段间留白（一段一段显示）。
  List<Widget> _segments() {
    final parts = widget.text
        .split(RegExp(r'\n{2,}'))
        .where((s) => s.trim().isNotEmpty);
    return [
      for (final p in parts)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: MarkdownBlock(
            data: p,
            selectable: true,
            config: kageMarkdownConfig(context),
          ),
        ),
    ];
  }
}

/// 思考中指示器：assistant 风格气泡里三个错峰弹跳的小圆点。
class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tok = KageDesignTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tok.space1),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(tok.radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) _dot(i, cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(int i, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          // 三点错峰：每点在自己的 1/3 周期内弹起
          final t = (_ctrl.value * 3 + i * 0.6) % 3;
          final v = (t < 1.0) ? sin(t * pi) : 0.0;
          return Opacity(
            opacity: 0.35 + 0.65 * v,
            child: Transform.translate(
              offset: Offset(0, -3 * v),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          );
        },
      ),
    );
  }
}
