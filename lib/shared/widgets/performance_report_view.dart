import 'package:flutter/material.dart';

import '../../core/analysis/performance_report.dart';

/// 性能分析结果可视化：整体评估 + 度量概览 + 问题列表（按严重度分组/排序） + 系统性建议。
class PerformanceReportView extends StatelessWidget {
  const PerformanceReportView({super.key, required this.report});

  final PerformanceReport report;

  static const _severityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
  static const _severityColors = <String, Color>{
    'critical': Color(0xFFD94F4F),
    'high': Color(0xFFE0703E),
    'medium': Color(0xFFE0A152),
    'low': Color(0xFF8A93A0),
  };
  static const _categoryColors = <String, Color>{
    '算法复杂度': Color(0xFFBB6BD7),
    '数据库性能': Color(0xFF3D7FD7),
    '内存与GC': Color(0xFF2FA9A0),
    '并发与锁': Color(0xFFE0703E),
    'I/O瓶颈': Color(0xFF9A7B4E),
    '资源使用': Color(0xFF7E8AA0),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final issues = [...report.issues]
      ..sort((a, b) => (_severityOrder[a.severity] ?? 9)
          .compareTo(_severityOrder[b.severity] ?? 9));
    final files = <String>{for (final i in issues) if (i.file.isNotEmpty) i.file};
    final severe = issues.where((i) =>
        i.severity == 'critical' || i.severity == 'high').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _overview(context, cs),
        const SizedBox(height: 12),
        _metrics(context, cs, total: issues.length, severe: severe, files: files.length),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('性能问题（${issues.length}）', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ...issues.map((i) => _issueTile(context, cs, i)),
        ],
        if (report.suggestions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _suggestions(context, cs, report.suggestions),
        ],
      ],
    );
  }

  Widget _overview(BuildContext context, ColorScheme cs) {
    final color = _severityColors[report.overall] ?? cs.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.speed_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('整体评估', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 6),
            _badge(report.overall, color),
          ]),
          const SizedBox(height: 6),
          Text(report.summary.isEmpty ? '（无）' : report.summary,
              style: const TextStyle(fontSize: 13, height: 1.6)),
        ])),
      ]),
    );
  }

  Widget _metrics(BuildContext context, ColorScheme cs,
      {required int total, required int severe, required int files}) {
    return Row(children: [
      Expanded(child: _metricCard(cs, '问题总数', '$total', Icons.flag_outlined)),
      const SizedBox(width: 10),
      Expanded(child: _metricCard(cs, '严重问题', '$severe', Icons.priority_high,
          accent: severe > 0 ? const Color(0xFFD94F4F) : null)),
      const SizedBox(width: 10),
      Expanded(child: _metricCard(cs, '影响文件', '$files', Icons.description_outlined)),
    ]);
  }

  Widget _metricCard(ColorScheme cs, String label, String value, IconData icon, {Color? accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: accent ?? cs.primary),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accent ?? cs.onSurface)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _issueTile(BuildContext context, ColorScheme cs, PerformanceIssue i) {
    final sevColor = _severityColors[i.severity] ?? const Color(0xFF8A93A0);
    final catColor = _categoryColors[i.category] ?? const Color(0xFF7E8AA0);
    final loc = i.file.isEmpty ? '未知位置' : (i.line == null ? i.file : '${i.file}:${i.line}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
        dense: true,
        leading: Container(width: 4, height: 30, decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(2))),
        title: Row(children: [
          Expanded(child: Text(i.title.isEmpty ? '（无标题）' : i.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            _badge(i.severity, sevColor),
            const SizedBox(width: 6),
            _badge(i.category, catColor),
            const SizedBox(width: 6),
            Icon(Icons.location_on_outlined, size: 11, color: cs.onSurfaceVariant),
            const SizedBox(width: 2),
            Expanded(child: Text(loc, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontFamily: 'monospace'))),
          ]),
        ),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (i.description.isNotEmpty) ...[
                Text('问题描述', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(i.description, style: const TextStyle(fontSize: 12, height: 1.6)),
              ],
              if (i.suggestion.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('优化建议', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
                const SizedBox(height: 4),
                Text(i.suggestion, style: const TextStyle(fontSize: 12, height: 1.6)),
              ],
            ],
          )),
        ],
      ),
    );
  }

  Widget _suggestions(BuildContext context, ColorScheme cs, List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tips_and_updates_outlined, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text('系统性优化建议', style: Theme.of(context).textTheme.labelMedium),
        ]),
        const SizedBox(height: 8),
        ...items.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ', style: TextStyle(fontSize: 12, color: cs.primary)),
                Expanded(child: Text(s, style: const TextStyle(fontSize: 12, height: 1.5))),
              ]),
            )),
      ]),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color, height: 1.4)),
    );
  }
}
