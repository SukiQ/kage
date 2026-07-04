import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/kage_icons.dart';

/// 自绘无边框标题栏：左侧 [leading]/[title] + [actions]，右侧窗口控制按钮。
/// 中间标题区可拖拽移动窗口，双击切换最大化。作为 Scaffold.appBar 使用。
class KageTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const KageTitleBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        border: Border(bottom: BorderSide(color: t.colorScheme.outline)),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => windowManager.startDragging(),
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DefaultTextStyle.merge(
                    style: t.textTheme.titleSmall ?? const TextStyle(),
                    child: title ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
          ...actions,
          const SizedBox(width: 4),
          const _WindowButtons(),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WinBtn(
          icon: const Icon(KageIcons.winMinimize, size: 14),
          tooltip: '最小化',
          onPressed: () => windowManager.minimize(),
        ),
        _WinBtn(
          icon: const Icon(KageIcons.winMaximize, size: 13),
          tooltip: '最大化/还原',
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WinBtn(
          icon: const Icon(KageIcons.winClose, size: 14),
          tooltip: '关闭',
          hoverColor: Theme.of(context).colorScheme.error,
          hoverForeground: Theme.of(context).colorScheme.onError,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WinBtn extends StatefulWidget {
  const _WinBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.hoverColor,
    this.hoverForeground,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final Color? hoverForeground;

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hover = false;

  Color get _fg => (_hover && widget.hoverForeground != null)
      ? widget.hoverForeground!
      : Theme.of(context).colorScheme.onSurfaceVariant;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 32,
            height: 30,
            decoration: BoxDecoration(
              color: _hover
                  ? (widget.hoverColor ??
                        Theme.of(context).colorScheme.surfaceContainerHigh)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: IconTheme(
              data: IconThemeData(color: _fg, size: 15),
              child: widget.icon,
            ),
          ),
        ),
      ),
    );
  }
}
