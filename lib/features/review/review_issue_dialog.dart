import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/sonar/sonar_file.dart';
import '../../core/sonar/sonar_prompt.dart';
import '../../core/sonar/sonar_report.dart';
import '../../data/models/project.dart';
import '../chat/chat_controller.dart';

/// 审查问题详情对话框：代码片段（高亮问题行）+ 完整描述 + 跳转/修复/忽略/关闭。
class ReviewIssueDialog extends ConsumerStatefulWidget {
  const ReviewIssueDialog({super.key, required this.issue, required this.project});

  final SonarIssue issue;
  final KageProject project;

  @override
  ConsumerState<ReviewIssueDialog> createState() => _ReviewIssueDialogState();
}

class _ReviewIssueDialogState extends ConsumerState<ReviewIssueDialog> {
  String? _snippet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSnippet();
  }

  String get _projectKey => widget.project.sonarProjectKey ?? '';

  String get _localPath => localPathOf(widget.issue, _projectKey, widget.project.path);

  Future<void> _loadSnippet() async {
    final s = await readSnippet(_localPath, widget.issue.line);
    if (mounted) {
      setState(() {
        _snippet = s;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final issue = widget.issue;
    final rel = shortComponent(issue.component, _projectKey);
    return AlertDialog(
      title: Row(
        children: [
          severityDot(issue.severity),
          const SizedBox(width: 8),
          Expanded(
            child: Text(issue.rule, style: Theme.of(context).textTheme.titleSmall),
          ),
          Text(
            issue.severity,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      content: SizedBox(
        width: 640,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue.message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => openInExplorer(_localPath),
              child: Text(
                '$rel:${issue.line ?? '-'}',
                style: TextStyle(
                  color: cs.primary,
                  decoration: TextDecoration.underline,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(child: _codeBlock()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _ignore(),
          child: const Text('忽略'),
        ),
        TextButton(
          onPressed: () => _fix(),
          child: const Text('让 Claude 修复'),
        ),
        TextButton(
          onPressed: () => openInExplorer(_localPath),
          child: const Text('跳转'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _codeBlock() {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('读取代码…'));
    }
    final s = _snippet;
    if (s == null) {
      return const Text(
        '文件未找到（SonarQube 路径可能与本地不一致）',
        style: TextStyle(color: Colors.grey),
      );
    }
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 320),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Text(
          s,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.5),
        ),
      ),
    );
  }

  void _ignore() {
    final cur = ref.read(ignoredIssuesProvider);
    ref.read(ignoredIssuesProvider.notifier).state =
        {...cur, issueKey(widget.issue)};
    if (mounted) Navigator.of(context).pop();
  }

  void _fix() {
    final issue = widget.issue;
    final rel = shortComponent(issue.component, _projectKey);
    final ctrl = ref.read(chatControllerProvider.notifier);
    ctrl.setPermissionMode('acceptEdits', widget.project);
    final prompt = '请修复以下 SonarQube 问题，直接修改文件：\n'
        '文件：$rel:${issue.line}\n'
        '规则：${issue.rule}（${issue.severity}）\n'
        '问题描述：${issue.message}\n'
        '请直接修复，无需冗长解释。';
    ctrl.send(prompt, widget.project);
    if (mounted) Navigator.of(context).pop();
  }
}

/// 严重度色点（BLOCKER 红 / CRITICAL 橙 / MAJOR 黄 / 其余灰）。
Widget severityDot(String severity) {
  final color = severityColor(severity);
  return Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

Color severityColor(String severity) => switch (severity) {
      'BLOCKER' => const Color(0xFFD94F4F),
      'CRITICAL' => const Color(0xFFE07A2D),
      'MAJOR' => const Color(0xFFE0A152),
      _ => const Color(0xFF9AA0A8),
    };
