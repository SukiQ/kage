import 'package:flutter/material.dart';

import '../../core/analysis/test_plan_report.dart';

/// 测试结果可视化：总览卡片 + 失败用例列表 + AI 解读。
class TestResultView extends StatelessWidget {
  const TestResultView({super.key, required this.result, this.interpretation});

  final TestExecutionResult result;
  final String? interpretation;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _summaryCard(context, cs),
      if (result.failures.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('失败用例（${result.failures.length}）', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ...result.failures.map((f) => _failureTile(context, cs, f)),
      ],
      if (interpretation != null && interpretation!.isNotEmpty) ...[
        const SizedBox(height: 16),
        _interpretationCard(context, cs, interpretation!),
      ],
    ]);
  }

  Widget _summaryCard(BuildContext context, ColorScheme cs) {
    final ok = result.success;
    final accent = ok ? const Color(0xFF3DAA6E) : const Color(0xFFD94F4F);
    final passRate = result.total == 0 ? 0.0 : result.passed / result.total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(ok ? '全部通过' : '存在失败',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
          const Spacer(),
          Text('耗时 ${result.duration.inSeconds}s',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _stat(cs, '总数', result.total, cs.onSurface)),
          Expanded(child: _stat(cs, '成功', result.passed, const Color(0xFF3DAA6E))),
          Expanded(child: _stat(cs, '失败', result.failed, const Color(0xFFD94F4F))),
          Expanded(child: _stat(cs, '跳过', result.skipped, const Color(0xFF8A93A0))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: passRate,
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest,
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text('通过率 ${(passRate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _stat(ColorScheme cs, String label, int value, Color color) {
    return Column(children: [
      Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
    ]);
  }

  Widget _failureTile(BuildContext context, ColorScheme cs, TestFailure f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(14, 0, 12, 0),
        dense: true,
        leading: Icon(Icons.close, size: 16, color: cs.error),
        title: Text(f.name.isEmpty ? '（未命名测试）' : f.name,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (f.error.isNotEmpty) ...[
                Text('错误', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.error)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(f.error,
                      style: TextStyle(fontSize: 11, height: 1.5, color: cs.onErrorContainer, fontFamily: 'monospace')),
                ),
              ],
              if (f.stackTrace.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('堆栈', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: SelectableText(f.stackTrace,
                        style: TextStyle(fontSize: 10, height: 1.4, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
                  ),
                ),
              ],
            ],
          )),
        ],
      ),
    );
  }

  Widget _interpretationCard(BuildContext context, ColorScheme cs, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_awesome_outlined, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text('AI 解读', style: Theme.of(context).textTheme.labelMedium),
        ]),
        const SizedBox(height: 8),
        SelectableText(text, style: const TextStyle(fontSize: 12, height: 1.6)),
      ]),
    );
  }
}
