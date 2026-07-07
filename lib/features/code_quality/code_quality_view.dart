import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/analysis_dimension.dart';
import '../../core/analysis/analysis_prompt.dart';
import '../../core/analysis/analysis_session_controller.dart';
import '../../core/scanners/scan_result.dart';
import '../../data/models/issue_record.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/analysis_panel.dart';

class CodeQualityView extends ConsumerStatefulWidget {
  const CodeQualityView({super.key, required this.project});
  final KageProject project;

  @override
  ConsumerState<CodeQualityView> createState() => _CodeQualityViewState();
}

class _CodeQualityViewState extends ConsumerState<CodeQualityView> {
  bool _showAi = false;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(activeScanResultProvider);
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // 主内容区
        Expanded(
          child: Column(
            children: [
              _toolbar(context, cs, result),
              Expanded(
                child: result == null
                    ? _empty(context, cs)
                    : _body(context, cs, result),
              ),
            ],
          ),
        ),
        // AI 修复侧边栏
        if (_showAi)
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: cs.outlineVariant)),
            ),
            child: const AnalysisPanel(dimension: AnalysisDimension.codeQuality),
          ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, ColorScheme cs, ScanResult? result) {
    final session = ref.watch(analysisSessionProvider(AnalysisDimension.codeQuality));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.code_outlined, size: 18),
          const SizedBox(width: 8),
          Text('代码质量', style: Theme.of(context).textTheme.titleSmall),
          if (result != null) ...[
            const SizedBox(width: 12),
            _metricChip('Bugs', result.metrics.bugs, const Color(0xFFD94F4F), cs),
            const SizedBox(width: 6),
            _metricChip('代码异味', result.metrics.codeSmells, const Color(0xFFE0A152), cs),
            const SizedBox(width: 6),
            _metricChip('技术债', result.metrics.technicalDebtMinutes != null
                ? _fmtDebt(result.metrics.technicalDebtMinutes!)
                : null, const Color(0xFF6B7FD7), cs),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: result == null || session.running
                ? null
                : () => _fixAll(result),
            icon: session.running
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.build_outlined, size: 16),
            label: Text(session.running ? '一键修复中…' : '一键修复'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_showAi ? Icons.close_fullscreen_outlined : Icons.open_in_new_outlined, size: 16),
            tooltip: _showAi ? '收起面板' : '展开面板',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _showAi = !_showAi),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, ColorScheme cs) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.code_outlined, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('请先在总览页执行扫描'),
        ]),
      );

  Widget _body(BuildContext context, ColorScheme cs, ScanResult result) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 指标概览
          _metricsSection(context, cs, result),
          const SizedBox(height: 20),
          // 严重度分布
          if (result.severityCounts.isNotEmpty) ...[
            _severitySection(context, cs, result),
            const SizedBox(height: 20),
          ],
          // 问题列表（按严重度排序，支持修复/忽略）
          _issueList(context, cs, result),
        ],
      ),
    );
  }

  Widget _metricsSection(BuildContext context, ColorScheme cs, ScanResult result) {
    final m = result.metrics;
    final cards = <_MetricItem>[
      if (m.bugs != null) _MetricItem('Bugs', '${m.bugs}', const Color(0xFFD94F4F), Icons.bug_report_outlined),
      if (m.codeSmells != null) _MetricItem('代码异味', '${m.codeSmells}', const Color(0xFFE0A152), Icons.sentiment_dissatisfied_outlined),
      if (m.duplicatedLinesDensity != null) _MetricItem('重复率', '${m.duplicatedLinesDensity!.toStringAsFixed(1)}%', const Color(0xFF9AA0A8), Icons.content_copy_outlined),
      if (m.technicalDebtMinutes != null) _MetricItem('技术债', _fmtDebt(m.technicalDebtMinutes!), const Color(0xFF6B7FD7), Icons.schedule_outlined),
      if (m.reliabilityRating != null) _MetricItem('可靠性', m.reliabilityRating!, const Color(0xFF3DAA6E), Icons.verified_outlined),
      if (m.maintainabilityRating != null) _MetricItem('可维护性', m.maintainabilityRating!, const Color(0xFF6B7FD7), Icons.build_outlined),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 10, runSpacing: 10, children: cards.map(_buildMetricCard).toList());
  }

  Widget _buildMetricCard(_MetricItem item) {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          width: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 4),
              Expanded(child: Text(item.label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
            ]),
            const SizedBox(height: 6),
            Text(item.value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: item.color)),
          ]),
        );
      },
    );
  }

  Widget _severitySection(BuildContext context, ColorScheme cs, ScanResult result) {
    final counts = result.severityCounts;
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    final segs = [
      ('BLOCKER', const Color(0xFFD94F4F)),
      ('CRITICAL', const Color(0xFFE07A2D)),
      ('MAJOR', const Color(0xFFE0A152)),
      ('MINOR', const Color(0xFF9AA0A8)),
      ('INFO', const Color(0xFFBBBFC4)),
    ].where((e) => (counts[e.$1] ?? 0) > 0).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('严重度分布（共 $total 条）', style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Row(
          children: segs.map((s) {
            final pct = (counts[s.$1] ?? 0) / total;
            return Flexible(
              flex: ((pct * 1000).round()).clamp(1, 1000),
              child: Tooltip(
                message: '${s.$1}: ${counts[s.$1]}',
                child: Container(height: 10, color: s.$2),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 6),
      Wrap(
        spacing: 14,
        children: segs.map((s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: s.$2)),
          const SizedBox(width: 4),
          Text('${s.$1} ${counts[s.$1]}', style: const TextStyle(fontSize: 11)),
        ])).toList(),
      ),
    ]);
  }

  /// 扫描结果 → 临时 IssueRecord（issueRecordsProvider 为空时回退使用）。
  List<IssueRecord> _recordsFromScan(ScanResult result) => result.issues
      .map((i) => IssueRecord(
            id: i.key,
            projectId: widget.project.id,
            scannerType: i.scannerType,
            issueKey: i.key,
            severity: i.severity.label,
            type: i.type.name,
            component: i.component,
            line: i.line,
            rule: i.rule,
            message: i.message,
            effort: i.effort,
            status: IssueStatus.open,
            createdAt: result.scannedAt,
            updatedAt: result.scannedAt,
          ))
      .toList();

  Widget _issueList(BuildContext context, ColorScheme cs, ScanResult result) {
    final stored = ref.watch(issueRecordsProvider);
    final displayList = stored.isNotEmpty ? stored : _recordsFromScan(result);

    if (displayList.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('问题清单（${displayList.length} 条）', style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 8),
      ...displayList.take(50).map((r) => _issueTile(context, cs, r)),
    ]);
  }

  Widget _issueTile(BuildContext context, ColorScheme cs, IssueRecord r) {
    final sevColor = _sevColor(r.severity);
    final running = ref.watch(analysisSessionProvider(AnalysisDimension.codeQuality)).running;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: sevColor)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                '${r.component}:${r.line ?? '-'}  ·  ${r.rule}',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (r.status == IssueStatus.open)
            Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                onPressed: running ? null : () => _showFixDialog(r),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3DAA6E),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('修复', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: running ? null : () => _ignore(r),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('忽略', style: TextStyle(fontSize: 12)),
              ),
            ])
          else if (r.status == IssueStatus.ignored)
            Row(mainAxisSize: MainAxisSize.min, children: [
              _StatusChip(status: r.status),
              const SizedBox(width: 4),
              TextButton(
                onPressed: running ? null : () => _restore(r),
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重新计入', style: TextStyle(fontSize: 12)),
              ),
            ])
          else
            _StatusChip(status: r.status),
        ]),
      ),
    );
  }

  // ── 操作：修复 / 忽略 / 一键修复 ────────────────────────────────────────────

  Future<void> _refreshIssues() async {
    final repo = await ref.read(issueRepositoryProvider.future);
    final records = await repo.forProject(widget.project.id);
    if (mounted) ref.read(issueRecordsProvider.notifier).state = records;
  }

  Future<void> _ignore(IssueRecord r) async {
    final repo = await ref.read(issueRepositoryProvider.future);
    await repo.updateStatus(widget.project.id, r.issueKey, IssueStatus.ignored);
    await _refreshIssues();
  }

  /// 重新计入：把已忽略的问题恢复为待处理。
  Future<void> _restore(IssueRecord r) async {
    final repo = await ref.read(issueRepositoryProvider.future);
    await repo.updateStatus(widget.project.id, r.issueKey, IssueStatus.open);
    await _refreshIssues();
  }

  /// 单个修复：弹窗填写附言（按 rule 预填/记忆）→ 调 AI 修复 → 标记已修复。
  Future<void> _showFixDialog(IssueRecord r) async {
    final noteRepo = await ref.read(ruleNoteRepositoryProvider.future);
    if (!mounted) return;
    final controller = TextEditingController(text: noteRepo.getNote(r.rule) ?? '');
    final cs = Theme.of(context).colorScheme;

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 修复问题'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.message, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${r.component}:${r.line ?? '-'}  ·  ${r.rule}',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '修复附言（可选）',
                  helperText: '对该类问题的修复方式/偏好，相同错误码将自动复用',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
            label: const Text('开始修复'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return; // 用户取消

    // 持久化附言（按 rule 全局记忆）
    await noteRepo.setNote(r.rule, note);

    setState(() => _showAi = true);
    await ref.read(analysisSessionProvider(AnalysisDimension.codeQuality).notifier).startFix(
          project: widget.project,
          prompt: AnalysisPrompt.buildFixSingleMessage(r, note),
          onComplete: () async {
            final repo = await ref.read(issueRepositoryProvider.future);
            await repo.updateStatus(
              widget.project.id,
              r.issueKey,
              IssueStatus.fixed,
              comment: note.isEmpty ? null : note,
            );
            await _refreshIssues();
          },
        );
  }

  /// 一键修复：调 AI 批量修复所有待处理（open）问题。
  Future<void> _fixAll(ScanResult result) async {
    final stored = ref.read(issueRecordsProvider);
    final all = stored.isNotEmpty ? stored : _recordsFromScan(result);
    final openIssues = all.where((r) => r.status == IssueStatus.open).toList();
    if (openIssues.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有待处理的问题'), duration: Duration(seconds: 2)),
      );
      return;
    }
    final noteRepo = await ref.read(ruleNoteRepositoryProvider.future);
    if (!mounted) return;
    final issueKeys = openIssues.map((e) => e.issueKey).toList();

    setState(() => _showAi = true);
    await ref.read(analysisSessionProvider(AnalysisDimension.codeQuality).notifier).startFix(
          project: widget.project,
          prompt: AnalysisPrompt.buildFixAllMessage(openIssues, noteRepo.all),
          onComplete: () async {
            final repo = await ref.read(issueRepositoryProvider.future);
            await repo.markFixed(widget.project.id, issueKeys);
            await _refreshIssues();
          },
        );
  }

  Widget _metricChip(String label, dynamic value, Color color, ColorScheme cs) {
    if (value == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Color _sevColor(String s) => switch (s) {
        'BLOCKER' => const Color(0xFFD94F4F),
        'CRITICAL' => const Color(0xFFE07A2D),
        'MAJOR' => const Color(0xFFE0A152),
        _ => const Color(0xFF9AA0A8),
      };

  String _fmtDebt(int min) {
    if (min < 60) return '${min}min';
    if (min < 480) return '${(min / 60).toStringAsFixed(1)}h';
    return '${(min / 480).toStringAsFixed(1)}d';
  }
}

class _MetricItem {
  const _MetricItem(this.label, this.value, this.color, this.icon);
  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final IssueStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (fg, bg) = switch (status) {
      IssueStatus.open => (cs.error, cs.error.withValues(alpha: 0.12)),
      IssueStatus.inProgress => (const Color(0xFF6B7FD7), const Color(0xFF6B7FD7).withValues(alpha: 0.12)),
      IssueStatus.fixed => (const Color(0xFF3DAA6E), const Color(0xFF3DAA6E).withValues(alpha: 0.12)),
      _ => (cs.onSurfaceVariant, cs.onSurfaceVariant.withValues(alpha: 0.1)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
