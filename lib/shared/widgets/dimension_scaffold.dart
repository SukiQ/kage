import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/analysis_dimension.dart';
import '../../core/analysis/analysis_session_controller.dart';
import '../../data/models/project.dart';
import 'analysis_panel.dart';

/// 以 AI 分析为主的维度脚手架（架构/性能/测试共用）。
/// 左侧展示维度说明与要点，右侧可展开 AI 分析面板。
class DimensionScaffold extends ConsumerStatefulWidget {
  const DimensionScaffold({
    super.key,
    required this.project,
    required this.dimension,
    required this.icon,
    required this.highlights,
  });

  final KageProject project;
  final AnalysisDimension dimension;
  final IconData icon;

  /// 分析要点列表（标题 + 描述）
  final List<(String, String)> highlights;

  @override
  ConsumerState<DimensionScaffold> createState() => _DimensionScaffoldState();
}

class _DimensionScaffoldState extends ConsumerState<DimensionScaffold> {
  bool _showAi = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _toolbar(context, cs),
              Expanded(child: _body(context, cs)),
            ],
          ),
        ),
        if (_showAi)
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: cs.outlineVariant)),
            ),
            child: AnalysisPanel(dimension: widget.dimension),
          ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, ColorScheme cs) {
    final result = ref.watch(activeScanResultProvider);
    final session = ref.watch(analysisSessionProvider(widget.dimension));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 18),
          const SizedBox(width: 8),
          Text(widget.dimension.label, style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          FilledButton.icon(
            onPressed: session.running
                ? null
                : () async {
                    setState(() => _showAi = true);
                    await ref
                        .read(analysisSessionProvider(widget.dimension).notifier)
                        .startAnalysis(
                          project: widget.project,
                          dimension: widget.dimension,
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

  Widget _body(BuildContext context, ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 32, color: cs.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.dimension.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(widget.dimension.description,
                          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('分析要点', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          ...widget.highlights.map((h) => _highlightTile(context, cs, h.$1, h.$2)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '点击右上角「AI 分析」，让 Claude 深入分析项目代码并给出具体建议。',
                    style: TextStyle(fontSize: 13, color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _highlightTile(BuildContext context, ColorScheme cs, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
