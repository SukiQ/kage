import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/architecture_ai_analyzer.dart';
import '../../core/analysis/project_architecture_analyzer.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/architecture_graph_view.dart';

enum _ArchState { idle, analyzing, done, error }

class ArchAnalysisView extends ConsumerStatefulWidget {
  const ArchAnalysisView({super.key, required this.project});
  final KageProject project;

  @override
  ConsumerState<ArchAnalysisView> createState() => _ArchAnalysisViewState();
}

class _ArchAnalysisViewState extends ConsumerState<ArchAnalysisView> {
  _ArchState _state = _ArchState.idle;
  ArchitectureGraph? _graph;
  String? _error;
  final _tools = <String>[];

  @override
  void didUpdateWidget(covariant ArchAnalysisView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id ||
        oldWidget.project.path != widget.project.path) {
      _graph = null;
      _error = null;
      _tools.clear();
      _state = _ArchState.idle;
    }
  }

  Future<void> _runAi() async {
    final exec = await ref.read(claudeExecutableProvider.future);
    if (exec == null) {
      if (mounted) {
        setState(() {
          _error = '未检测到 claude CLI，请在设置中配置路径。';
          _state = _ArchState.error;
        });
      }
      return;
    }
    final model = ref.read(activeModelProvider);
    final analyzer = ArchitectureAiAnalyzer(claudeExecutable: exec, model: model);

    setState(() {
      _state = _ArchState.analyzing;
      _graph = null;
      _error = null;
      _tools.clear();
    });

    try {
      final graph = await analyzer.analyze(
        project: widget.project,
        onTool: (line) {
          _tools.insert(0, line);
          if (_tools.length > 12) _tools.removeLast();
          if (mounted) setState(() {});
        },
      );
      if (mounted) {
        setState(() {
          _graph = graph;
          _state = _ArchState.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _state = _ArchState.error;
        });
      }
    }
  }

  // ── 导出架构分析报告（Markdown）─────────────────────────────────────────────

  Future<void> _exportReport() async {
    final graph = _graph;
    if (graph == null) return;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出架构分析报告',
      fileName: '架构分析报告-${widget.project.name}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
      lockParentWindow: true,
    );
    if (path == null) return; // 用户取消
    try {
      await File(path).writeAsString(_buildReport(graph));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出报告：$path'), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    }
  }

  String _buildReport(ArchitectureGraph graph) {
    final buf = StringBuffer();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts = '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';
    buf.writeln('# 架构分析报告 · ${widget.project.name}');
    buf.writeln();
    buf.writeln('> 生成时间：$ts');
    buf.writeln();
    buf.writeln('## 架构摘要');
    buf.writeln(graph.summary.isEmpty ? '（无）' : graph.summary);
    buf.writeln();
    buf.writeln('## 模块（节点）');
    buf.writeln('| 模块 | 层级 | 职责 |');
    buf.writeln('|------|------|------|');
    for (final n in graph.nodes) {
      buf.writeln('| ${_cell(n.label)} | ${_cell(n.layer)} | ${_cell(n.description)} |');
    }
    buf.writeln();
    buf.writeln('## 模块依赖');
    if (graph.edges.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (final e in graph.edges) {
        buf.writeln('- ${_cell(e.from)} → ${_cell(e.to)}：${_cell(e.label)}');
      }
    }
    buf.writeln();
    buf.writeln('## AI 辅助开发提示');
    if (graph.developmentHints.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (final h in graph.developmentHints) {
        buf.writeln('- ${_cell(h)}');
      }
    }
    return buf.toString();
  }

  String _cell(String s) => s.replaceAll('|', '\\|').replaceAll('\n', ' ');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      _toolbar(context, cs),
      Expanded(child: _body(context, cs)),
    ]);
  }

  Widget _toolbar(BuildContext context, ColorScheme cs) {
    final busy = _state == _ArchState.analyzing;
    final canExport = _state == _ArchState.done && _graph != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      child: Row(children: [
        const Icon(Icons.account_tree_outlined, size: 18),
        const SizedBox(width: 8),
        Text('架构分析', style: Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        FilledButton.icon(
          onPressed: busy ? null : _runAi,
          icon: busy
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text(busy
              ? 'AI 分析中…'
              : (_state == _ArchState.done ? '重新分析' : 'AI 分析架构')),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.download_outlined, size: 18),
          tooltip: '导出架构报告',
          onPressed: canExport ? _exportReport : null,
        ),
      ]),
    );
  }

  Widget _body(BuildContext context, ColorScheme cs) {
    switch (_state) {
      case _ArchState.idle:
        return _center(cs, Icons.hub_outlined, '点击「AI 分析架构」，生成可视架构图');
      case _ArchState.analyzing:
        return _analyzingView(context, cs);
      case _ArchState.done:
        return _graphView(context, cs, _graph!);
      case _ArchState.error:
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _errorBanner(context, cs),
          ),
        );
    }
  }

  Widget _center(ColorScheme cs, IconData icon, String text) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  Widget _analyzingView(BuildContext context, ColorScheme cs) {
    final current = _tools.isEmpty ? '准备中…' : _tools.first;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(height: 16),
          const Text('AI 正在阅读项目代码、分析架构…',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_arrow_outlined, size: 14, color: cs.primary),
            const SizedBox(width: 4),
            Flexible(child: Text(current, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace'))),
          ]),
        ]),
      ),
    );
  }

  Widget _graphView(BuildContext context, ColorScheme cs, ArchitectureGraph graph) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: ArchitectureGraphView(graph: graph),
        ),
        const SizedBox(height: 16),
        if (graph.summary.isNotEmpty) _section(context, cs, '架构摘要', graph.summary),
        if (graph.developmentHints.isNotEmpty) ...[
          const SizedBox(height: 12),
          _hints(context, cs, graph.developmentHints),
        ],
      ],
    );
  }

  Widget _section(BuildContext context, ColorScheme cs, String title, String body) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(fontSize: 12, height: 1.6, color: cs.onSurface)),
      ]),
    );
  }

  Widget _hints(BuildContext context, ColorScheme cs, List<String> hints) {
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
          Text('AI 辅助开发提示', style: Theme.of(context).textTheme.labelMedium),
        ]),
        const SizedBox(height: 8),
        ...hints.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ', style: TextStyle(fontSize: 12, color: cs.primary)),
                Expanded(child: Text(h, style: const TextStyle(fontSize: 12, height: 1.5))),
              ]),
            )),
      ]),
    );
  }

  Widget _errorBanner(BuildContext context, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.error_outline, size: 16, color: cs.error),
          const SizedBox(width: 6),
          Text('AI 分析失败', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.error)),
          const Spacer(),
          TextButton.icon(
            onPressed: _runAi,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('重试', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ]),
        const SizedBox(height: 6),
        SelectableText(_error ?? '未知错误',
            style: TextStyle(fontSize: 11, color: cs.onErrorContainer, height: 1.5, fontFamily: 'monospace')),
      ]),
    );
  }
}
