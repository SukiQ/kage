import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/analysis_dimension.dart';
import '../../core/analysis/analysis_session_controller.dart';
import '../../core/scanners/scan_result.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/analysis_panel.dart';

class SecurityReviewView extends ConsumerStatefulWidget {
  const SecurityReviewView({super.key, required this.project});
  final KageProject project;

  @override
  ConsumerState<SecurityReviewView> createState() => _SecurityReviewViewState();
}

class _SecurityReviewViewState extends ConsumerState<SecurityReviewView> {
  bool _showAi = false;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(activeScanResultProvider);
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
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
        if (_showAi)
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: cs.outlineVariant)),
            ),
            child: const AnalysisPanel(dimension: AnalysisDimension.securityReview),
          ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, ColorScheme cs, ScanResult? result) {
    final session = ref.watch(analysisSessionProvider(AnalysisDimension.securityReview));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 18),
          const SizedBox(width: 8),
          Text('安全审查', style: Theme.of(context).textTheme.titleSmall),
          if (result != null) ...[
            const SizedBox(width: 12),
            _chip('漏洞', result.metrics.vulnerabilities, const Color(0xFFD94F4F), cs),
            const SizedBox(width: 6),
            _chip('安全热点', result.metrics.securityHotspots, const Color(0xFFE07A2D), cs),
            const SizedBox(width: 6),
            if (result.metrics.securityRating != null)
              _ratingChip('安全评级', result.metrics.securityRating!, cs),
          ],
          const Spacer(),
          FilledButton.icon(
            onPressed: result == null || session.running
                ? null
                : () async {
                    setState(() => _showAi = true);
                    await ref
                        .read(analysisSessionProvider(AnalysisDimension.securityReview).notifier)
                        .startAnalysis(
                          project: widget.project,
                          dimension: AnalysisDimension.securityReview,
                          scanResult: result,
                        );
                  },
            icon: session.running
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_outlined, size: 16),
            label: Text(session.running ? 'AI 分析中…' : 'AI 分析'),
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
          Icon(Icons.shield_outlined, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('请先在总览页执行扫描'),
        ]),
      );

  Widget _body(BuildContext context, ColorScheme cs, ScanResult result) {
    final vulns = result.issues
        .where((i) => i.type == ScanIssueType.vulnerability || i.type == ScanIssueType.securityHotspot)
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 安全指标
          _metricsRow(context, cs, result),
          const SizedBox(height: 20),
          // 安全问题列表
          Text('安全问题（${vulns.length} 条）', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          if (vulns.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF3DAA6E).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3DAA6E).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined, color: Color(0xFF3DAA6E), size: 20),
                  SizedBox(width: 8),
                  Text('未发现安全漏洞', style: TextStyle(color: Color(0xFF3DAA6E), fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else
            ...vulns.take(50).map((i) => _vulnTile(context, cs, i)),
        ],
      ),
    );
  }

  Widget _metricsRow(BuildContext context, ColorScheme cs, ScanResult result) {
    final m = result.metrics;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      if (m.vulnerabilities != null)
        _card(context, cs, '漏洞', '${m.vulnerabilities}', const Color(0xFFD94F4F), Icons.bug_report_outlined),
      if (m.securityHotspots != null)
        _card(context, cs, '安全热点', '${m.securityHotspots}', const Color(0xFFE07A2D), Icons.local_fire_department_outlined),
      if (m.securityRating != null)
        _card(context, cs, '安全评级', m.securityRating!, const Color(0xFF6B7FD7), Icons.grade_outlined),
    ]);
  }

  Widget _card(BuildContext context, ColorScheme cs, String label, String value, Color color, IconData icon) {
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _vulnTile(BuildContext context, ColorScheme cs, ScanIssue issue) {
    final isVuln = issue.type == ScanIssueType.vulnerability;
    final color = issue.severity == ScanSeverity.blocker || issue.severity == ScanSeverity.critical
        ? const Color(0xFFD94F4F)
        : const Color(0xFFE07A2D);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(
          isVuln ? Icons.security_outlined : Icons.local_fire_department_outlined,
          size: 18,
          color: color,
        ),
        title: Text(issue.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '${issue.component}:${issue.line ?? '-'}  ·  ${issue.rule}',
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
        trailing: Chip(
          label: Text(issue.severity.label, style: const TextStyle(fontSize: 10)),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          backgroundColor: color.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _chip(String label, int? value, Color color, ColorScheme cs) {
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

  Widget _ratingChip(String label, String rating, ColorScheme cs) {
    final color = switch (rating) {
      'A' => const Color(0xFF3DAA6E),
      'B' => const Color(0xFF6B7FD7),
      'C' => const Color(0xFFE0A152),
      _ => const Color(0xFFD94F4F),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $rating', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
