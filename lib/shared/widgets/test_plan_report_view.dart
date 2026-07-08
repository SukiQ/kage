import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/analysis/test_plan_report.dart';

/// 测试计划可视化：整体评估 + 覆盖率缺口 + 推荐用例列表
/// （每条可单独「运行测试」和「生成测试代码」） + 系统性建议。
class TestPlanReportView extends StatelessWidget {
  const TestPlanReportView({
    super.key,
    required this.report,
    this.caseRuns = const {},
    this.onRunTest,
    this.caseGens = const {},
    this.onGenTest,
  });

  final TestPlanReport report;

  /// 各用例的单独执行状态，key = "module::scenario"。
  final Map<String, CaseRunStatus> caseRuns;
  final void Function(RecommendedTestCase)? onRunTest;

  /// 各用例的代码生成状态，key = "module::scenario"。
  final Map<String, CaseGenStatus> caseGens;
  final void Function(RecommendedTestCase)? onGenTest;

  static const _priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
  static const _priorityColors = <String, Color>{
    'critical': Color(0xFFD94F4F),
    'high': Color(0xFFE0703E),
    'medium': Color(0xFFE0A152),
    'low': Color(0xFF8A93A0),
  };
  static const _categoryColors = <String, Color>{
    '边界值': Color(0xFF2FA9A0),
    '异常流程': Color(0xFFD94F4F),
    '状态转换': Color(0xFFBB6BD7),
    '并发场景': Color(0xFFE0703E),
    '性能压力': Color(0xFF9A7B4E),
    '安全漏洞': Color(0xFFB23A6B),
  };
  static const _testTypeColors = <String, Color>{
    '单元测试': Color(0xFF3D7FD7),
    '组件测试': Color(0xFF3DAA6E),
    '集成测试': Color(0xFFE0A152),
    '端到端测试': Color(0xFFBB6BD7),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cases = [...report.recommendedCases]
      ..sort((a, b) => (_priorityOrder[a.priority] ?? 9)
          .compareTo(_priorityOrder[b.priority] ?? 9));
    final cov = (report.coverageGaps.overallCoverage * 100).clamp(0, 100).toDouble();
    final overall = _overallFromCoverage(cov);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _overview(context, cs, overall),
      const SizedBox(height: 12),
      _coverageCard(context, cs, cov),
      if (cases.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('推荐测试用例（${cases.length}）', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ...cases.map((c) => _caseTile(context, cs, c)),
      ],
      if (report.suggestions.isNotEmpty) ...[
        const SizedBox(height: 16),
        _suggestions(context, cs, report.suggestions),
      ],
    ]);
  }

  String _overallFromCoverage(double cov) {
    if (cov >= 80) return 'good';
    if (cov >= 60) return 'medium';
    if (cov >= 40) return 'high';
    return 'critical';
  }

  Widget _overview(BuildContext context, ColorScheme cs, String overall) {
    final color = _priorityColors[overall] ?? cs.primary;
    final label = const {'good': '良好', 'medium': '中等', 'high': '偏高', 'critical': '严重'}[overall] ?? overall;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.science_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('整体评估', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(width: 6),
            _badge(label, color),
          ]),
          const SizedBox(height: 6),
          Text(report.summary.isEmpty ? '（无）' : report.summary,
              style: const TextStyle(fontSize: 13, height: 1.6)),
        ])),
      ]),
    );
  }

  Widget _coverageCard(BuildContext context, ColorScheme cs, double cov) {
    final modules = report.coverageGaps.highRiskModules;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('覆盖率估算', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const Spacer(),
          Text('${cov.toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.primary)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: cov / 100,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (modules.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('高风险模块（覆盖率不足）',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: modules
                .map((m) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD94F4F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFD94F4F).withValues(alpha: 0.3)),
                      ),
                      child: Text(m,
                          style: const TextStyle(
                              fontSize: 11, fontFamily: 'monospace', color: Color(0xFFD94F4F))),
                    ))
                .toList(),
          ),
        ],
      ]),
    );
  }

  Widget _caseTile(BuildContext context, ColorScheme cs, RecommendedTestCase c) {
    final key = '${c.module}::${c.scenario}';
    final run = caseRuns[key] ?? const CaseRunStatus();
    final gen = caseGens[key] ?? const CaseGenStatus();
    final pColor = _priorityColors[c.priority] ?? const Color(0xFF8A93A0);
    final cColor = _categoryColors[c.category] ?? const Color(0xFF7E8AA0);
    final tColor = _testTypeColors[c.testType] ?? const Color(0xFF7E8AA0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IntrinsicHeight(
          child: Container(
            width: 4,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: pColor, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c.scenario.isEmpty ? '（无标题）' : c.scenario,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _badge(c.priority, pColor),
            _badge(c.category, cColor),
            _badge(c.testType, tColor),
            if (c.module.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_on_outlined, size: 11, color: cs.onSurfaceVariant),
                const SizedBox(width: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(c.module, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
                ),
              ]),
          ]),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(c.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.5)),
          ],
          if (c.whyImportant.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('重要性：${c.whyImportant}', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, height: 1.4, color: cs.onSurfaceVariant)),
          ],
          if (run.state == CaseRunState.done && run.result != null)
            _inlineResult(context, cs, run.result!)
          else if (run.state == CaseRunState.error)
            _inlineError(context, cs, run.error),
          if (gen.state == CaseGenState.done && gen.code != null)
            _codeBlock(context, cs, gen, run, () => onRunTest?.call(c))
          else if (gen.state == CaseGenState.error)
            _inlineError(context, cs, gen.error),
        ])),
        const SizedBox(width: 4),
        Column(mainAxisSize: MainAxisSize.min, children: [
          _runButton(cs, run, () => onRunTest?.call(c)),
          const SizedBox(height: 2),
          _genButton(cs, gen, () => onGenTest?.call(c)),
        ]),
      ]),
    );
  }

  Widget _runButton(ColorScheme cs, CaseRunStatus s, VoidCallback onTap) {
    if (s.state == CaseRunState.running) {
      return const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    }
    IconData icon;
    Color color;
    String tip;
    if (s.state == CaseRunState.done) {
      final ok = s.result?.success ?? false;
      icon = ok ? Icons.check_circle : Icons.cancel;
      color = ok ? const Color(0xFF3DAA6E) : const Color(0xFFD94F4F);
      tip = '重新运行';
    } else if (s.state == CaseRunState.error) {
      icon = Icons.error_outline;
      color = cs.error;
      tip = '重新运行';
    } else {
      icon = Icons.play_circle_outline;
      color = cs.primary;
      tip = '运行此用例的测试';
    }
    return IconButton(
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      icon: Icon(icon, size: 22, color: color),
      tooltip: tip,
      onPressed: onTap,
    );
  }

  Widget _genButton(ColorScheme cs, CaseGenStatus s, VoidCallback onTap) {
    if (s.state == CaseGenState.generating) {
      return const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2));
    }
    IconData icon;
    Color color;
    String tip;
    if (s.state == CaseGenState.done) {
      icon = Icons.check_circle;
      color = const Color(0xFF3DAA6E);
      tip = '重新生成';
    } else if (s.state == CaseGenState.error) {
      icon = Icons.error_outline;
      color = cs.error;
      tip = '重新生成';
    } else {
      icon = Icons.code;
      color = cs.primary;
      tip = '生成测试代码';
    }
    return IconButton(
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
      icon: Icon(icon, size: 22, color: color),
      tooltip: tip,
      onPressed: onTap,
    );
  }

  Widget _inlineResult(BuildContext context, ColorScheme cs, TestExecutionResult r) {
    final ok = r.success;
    final color = ok ? const Color(0xFF3DAA6E) : const Color(0xFFD94F4F);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 14, color: color),
          const SizedBox(width: 6),
          Text(ok ? '测试通过' : '存在失败',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          Text('成功 ${r.passed} ｜ 失败 ${r.failed} ｜ 跳过 ${r.skipped}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),
        if (!ok && r.failures.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...r.failures.take(3).map((f) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(f.error.isEmpty ? f.name : '${f.name}\n${f.error}',
                    style: TextStyle(
                        fontSize: 10, height: 1.4, fontFamily: 'monospace', color: cs.onSurfaceVariant)),
              )),
        ],
      ]),
    );
  }

  Widget _inlineError(BuildContext context, ColorScheme cs, String? error) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline, size: 14, color: cs.error),
        const SizedBox(width: 6),
        Expanded(child: SelectableText(error ?? '失败',
            style: TextStyle(fontSize: 11, height: 1.4, color: cs.onErrorContainer, fontFamily: 'monospace'))),
      ]),
    );
  }

  Widget _codeBlock(BuildContext context, ColorScheme cs, CaseGenStatus gen, CaseRunStatus run, VoidCallback? onRun) {
    final code = gen.code!;
    final running = run.state == CaseRunState.running;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
          child: Row(children: [
            Icon(Icons.code, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Text('生成的测试代码', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            if (gen.filePath != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle, size: 12, color: const Color(0xFF3DAA6E)),
              const SizedBox(width: 3),
              Flexible(
                child: Text('已写入 ${gen.filePath}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: const Color(0xFF3DAA6E), fontFamily: 'monospace')),
              ),
            ] else if (gen.error != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text('写入项目失败：${gen.error}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: cs.error)),
              ),
            ],
            const Spacer(),
            if (gen.filePath != null && onRun != null)
              IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: running
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.play_arrow, size: 16, color: cs.primary),
                tooltip: '运行此测试',
                onPressed: running ? null : onRun,
              ),
            IconButton(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              icon: Icon(Icons.copy_outlined, size: 16, color: cs.onSurfaceVariant),
              tooltip: '复制代码',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制测试代码'), duration: Duration(seconds: 2)),
                );
              },
            ),
          ]),
        ),
        Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 360),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: SingleChildScrollView(
            child: SelectableText(code,
                style: TextStyle(fontSize: 11, height: 1.5, fontFamily: 'monospace', color: cs.onSurface)),
          ),
        ),
      ]),
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
          Text('系统性测试建议', style: Theme.of(context).textTheme.labelMedium),
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
