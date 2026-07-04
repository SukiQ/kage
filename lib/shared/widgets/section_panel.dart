import 'package:flutter/material.dart';

import '../theme/kage_tokens.dart';

/// 简约现代分组面板：柔和圆角卡片（surfaceContainer 底，无硬边框），
/// 标题行 + 内容靠间距区分。替代三个侧栏面板里重复的结构。
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    required this.child,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final tok = KageDesignTokens.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: tok.space3),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(tok.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tok.space3,
              tok.space2,
              tok.space2,
              tok.space2,
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, SizedBox(width: tok.space1)],
                Text(title, style: t.textTheme.titleSmall),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(tok.space3, 0, tok.space3, tok.space3),
            child: child,
          ),
        ],
      ),
    );
  }
}
