import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/sonar/sonar_client.dart';
import '../../core/sonar/sonar_file.dart';
import '../../core/sonar/sonar_prompt.dart';
import '../../core/sonar/sonar_report.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/project.dart';
import '../../shared/theme/kage_icons.dart';
import '../chat/chat_controller.dart';
import '../review/review_issue_dialog.dart';

/// 侧栏菜单：新的会话 / 代码编译 / 代码审查 / 导出接口 / 历史会话（可折叠，无动画）。
class SidebarMenu extends ConsumerStatefulWidget {
  const SidebarMenu({super.key, required this.project});

  final KageProject project;

  @override
  ConsumerState<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends ConsumerState<SidebarMenu> {
  Future<List<ChatSessionMeta>>? _sessionsFuture;
  bool _historyExpanded = false;
  bool _reviewExpanded = false;

  @override
  void initState() {
    super.initState();
    _refreshSessions();
  }

  @override
  void didUpdateWidget(covariant SidebarMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) _refreshSessions();
  }

  void _refreshSessions() {
    _sessionsFuture = () async {
      final repo = await ref.read(sessionRepositoryProvider.future);
      return repo.forProject(widget.project.id);
    }();
    setState(() {});
  }

  Future<void> _send(String prompt) async {
    await ref
        .read(chatControllerProvider.notifier)
        .send(prompt, widget.project);
  }

  /// 代码审查：优先结合 SonarQube 报告喂 claude；未配置/拉取失败则降级为基础审查。
  Future<void> _startReview() async {
    final project = widget.project;
    final ctrl = ref.read(chatControllerProvider.notifier);
    final settings = await ref.read(settingsServiceProvider.future);
    final host = settings.sonarHost;
    final token = settings.sonarToken;
    final key = project.sonarProjectKey;
    if (host == null ||
        host.isEmpty ||
        token == null ||
        token.isEmpty ||
        key == null ||
        key.isEmpty) {
      await ctrl.send(_Prompts.review, project);
      return;
    }
    await ctrl.setInfo('正在拉取 SonarQube 报告…');
    try {
      final report = await SonarClient(
        host: host,
        token: token,
      ).fetchReport(key);
      ref.read(reviewReportProvider.notifier).state = report;
      ref.read(ignoredIssuesProvider.notifier).state = {};
      await ctrl.send(buildSonarReviewPrompt(report), project);
    } catch (e) {
      await ctrl.setInfo('SonarQube 拉取失败，改用基础审查');
      await ctrl.send(_Prompts.review, project);
    }
  }

  Future<void> _newSession() async {
    await ref.read(chatControllerProvider.notifier).startNewSession();
  }

  Future<void> _openSession(ChatSessionMeta meta) async {
    await ref
        .read(chatControllerProvider.notifier)
        .loadSession(meta, widget.project);
  }

  Future<void> _deleteSession(ChatSessionMeta meta) async {
    final repo = await ref.read(sessionRepositoryProvider.future);
    await repo.delete(meta.id);
    _refreshSessions();
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(chatControllerProvider).currentSessionMetaId;
    return SizedBox(
      width: 240,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        children: [
          _item(KageIcons.newSession, '新的会话', _newSession),
          _item(KageIcons.codeBuild, '代码编译', () => _send(_Prompts.compile)),
          _item(KageIcons.codeReview, '代码审查', _startReview),
          _item(KageIcons.exportApi, '导出接口', () => _send(_Prompts.exportApi)),
          const SizedBox(height: 4),
          const Divider(height: 1),
          _reviewHeader(),
          if (_reviewExpanded) _reviewList(),
          _item(
            KageIcons.history,
            '历史会话',
            () => setState(() => _historyExpanded = !_historyExpanded),
            trailing: Icon(
              _historyExpanded ? KageIcons.dropdown : KageIcons.chevronRight,
              size: 16,
            ),
          ),
          if (_historyExpanded)
            FutureBuilder<List<ChatSessionMeta>>(
              future: _sessionsFuture,
              builder: (_, snap) {
                if (!snap.hasData) {
                  return _hint('加载…');
                }
                final list = snap.data!;
                return Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      () {
                        final m = list[i];
                        return _TimelineItem(
                          isFirst: i == 0,
                          isLast: i == list.length - 1,
                          selected: m.id == currentId,
                          child: _item(
                            null,
                            m.title,
                            () => _openSession(m),
                            trailing: IconButton(
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(KageIcons.delete),
                              onPressed: () => _deleteSession(m),
                            ),
                          ),
                        );
                      }(),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _reviewHeader() {
    final report = ref.watch(reviewReportProvider);
    final ignored = ref.watch(ignoredIssuesProvider);
    final n = report == null
        ? 0
        : report.issues.where((i) => !ignored.contains(issueKey(i))).length;
    return _item(
      KageIcons.alert,
      '审查问题 ($n)',
      () => setState(() => _reviewExpanded = !_reviewExpanded),
      trailing: Icon(
        _reviewExpanded ? KageIcons.dropdown : KageIcons.chevronRight,
        size: 16,
      ),
    );
  }

  Widget _reviewList() {
    final report = ref.watch(reviewReportProvider);
    if (report == null) return _hint('暂无审查问题，点「代码审查」生成');
    final ignored = ref.watch(ignoredIssuesProvider);
    final issues = report.issues
        .where((i) => !ignored.contains(issueKey(i)))
        .toList();
    if (issues.isEmpty) return _hint('暂无审查问题');
    return Column(
      children: [for (final issue in issues) _reviewIssueTile(issue, report)],
    );
  }

  Widget _reviewIssueTile(SonarIssue issue, SonarReport report) {
    final cs = Theme.of(context).colorScheme;
    final rel = shortComponent(issue.component, report.projectKey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: cs.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (_) =>
                ReviewIssueDialog(issue: issue, project: widget.project),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            child: Row(
              children: [
                severityDot(issue.severity),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.rule,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$rel:${issue.line ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                      ),
                    ],
                  ),
                ),
                _iconAction(KageIcons.folderOpen, '跳转', () => _jumpIssue(issue)),
                _iconAction(KageIcons.tool, '让 Claude 修复', () => _fixIssue(issue)),
                _iconAction(KageIcons.delete, '忽略', () => _ignoreIssue(issue)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, String tip, VoidCallback onTap) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 14,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(icon),
      tooltip: tip,
      onPressed: onTap,
    );
  }

  void _jumpIssue(SonarIssue issue) {
    openInExplorer(localPathOf(
        issue, widget.project.sonarProjectKey ?? '', widget.project.path));
  }

  void _fixIssue(SonarIssue issue) {
    final key = widget.project.sonarProjectKey ?? '';
    final rel = shortComponent(issue.component, key);
    final ctrl = ref.read(chatControllerProvider.notifier);
    ctrl.setPermissionMode('acceptEdits', widget.project);
    ctrl.send(
      '请修复以下 SonarQube 问题，直接修改文件：\n'
      '文件：$rel:${issue.line}\n'
      '规则：${issue.rule}（${issue.severity}）\n'
      '问题描述：${issue.message}\n'
      '请直接修复，无需冗长解释。',
      widget.project,
    );
  }

  void _ignoreIssue(SonarIssue issue) {
    final cur = ref.read(ignoredIssuesProvider);
    ref.read(ignoredIssuesProvider.notifier).state = {...cur, issueKey(issue)};
  }

  /// 统一样式的菜单项：透明背景 + 图标（可空）+ 标题（+可选 trailing）。
  Widget _item(
    IconData? icon,
    String label,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          horizontalTitleGap: 6,
          leading: icon == null ? null : Icon(icon, size: 17),
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 6, 8, 6),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

/// 历史会话 timeline 项：左列竖线 + 节点圆点（垂直居中对齐会话项中线），右列为会话项。
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.child,
    required this.isFirst,
    required this.isLast,
    required this.selected,
  });

  final Widget child;
  final bool isFirst;
  final bool isLast;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineCol = cs.outline;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: isFirst
                      ? const SizedBox.shrink()
                      : Center(child: Container(width: 1.5, color: lineCol)),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? cs.primary : cs.surface,
                    border: Border.all(
                      color: selected ? cs.primary : lineCol,
                      width: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Center(child: Container(width: 1.5, color: lineCol)),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

abstract final class _Prompts {
  static const compile = '请对当前项目进行代码编译，并报告编译结果与遇到的错误。';
  static const review = '请对当前项目进行代码审查，重点关注：代码质量、潜在 Bug、安全风险、性能问题，并给出改进建议。';
  static const exportApi = '请分析当前项目，导出所有对外接口（API/类/函数），以文档形式列出其签名、参数、返回值与用途。';
}
