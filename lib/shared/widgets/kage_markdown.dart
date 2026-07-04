import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/a11y-dark.dart';
import 'package:flutter_highlight/themes/a11y-light.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../theme/kage_tokens.dart';

/// 构建 markdown_widget 的 [MarkdownConfig]：
/// - 链接 [LinkConfig.onTap] 由调用方提供（打开路径/URL）
/// - 代码块 [PreConfig.wrapper] 包裹为可折叠 + 语法高亮（按明暗选 a11y 主题）
/// - 其余继承 darkConfig / defaultConfig
MarkdownConfig kageMarkdownConfig(
  BuildContext context, {
  ValueChanged<String>? onLinkTap,
}) {
  final cs = Theme.of(context).colorScheme;
  final dark = cs.brightness == Brightness.dark;
  final tok = KageDesignTokens.of(context);
  final base =
      dark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
  return base.copy(configs: [
    LinkConfig(onTap: onLinkTap),
    PreConfig(
      theme: dark ? a11yDarkTheme : a11yLightTheme,
      textStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 12.5,
        height: 1.5,
      ),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(tok.radiusSmall),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      margin: const EdgeInsets.symmetric(vertical: 6),
      wrapper: (child, content, language) => _CollapsibleCode(
        content: content,
        language: language.isEmpty ? null : language,
        child: child,
      ),
    ),
  ]);
}

/// 可折叠代码块：包裹 markdown_widget 默认渲染（含语法高亮），
/// 超 8 行默认限高 + 展开按钮；顶部显示语言标签。
class _CollapsibleCode extends StatefulWidget {
  const _CollapsibleCode({
    required this.content,
    this.language,
    required this.child,
  });

  final Widget child;
  final String content;
  final String? language;

  @override
  State<_CollapsibleCode> createState() => _CollapsibleCodeState();
}

class _CollapsibleCodeState extends State<_CollapsibleCode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lines = widget.content.split('\n');
    final long = lines.length > 8;
    final showHeader = widget.language != null || long;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 0, 2),
            child: Row(
              children: [
                if (widget.language != null)
                  Text(
                    widget.language!,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                const Spacer(),
                if (long)
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? '收起' : '展开',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: long && !_expanded ? 180 : double.infinity,
          ),
          child: SingleChildScrollView(child: widget.child),
        ),
      ],
    );
  }
}
