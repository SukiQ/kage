import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/performance_ai_analyzer.dart';
import '../../core/analysis/performance_report.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/performance_report_view.dart';

enum _PerfState { idle, analyzing, done, error }

class PerfAnalysisView extends ConsumerStatefulWidget {
  const PerfAnalysisView({super.key, required this.project});
  final KageProject project;

  @override
  ConsumerState<PerfAnalysisView> createState() => _PerfAnalysisViewState();
}

class _PerfAnalysisViewState extends ConsumerState<PerfAnalysisView> {
  _PerfState _state = _PerfState.idle;
  PerformanceReport? _report;
  String? _error;
  final _tools = <String>[];

  @override
  void didUpdateWidget(covariant PerfAnalysisView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id ||
        oldWidget.project.path != widget.project.path) {
      _report = null;
      _error = null;
      _tools.clear();
      _state = _PerfState.idle;
    }
  }

  Future<void> _runAi() async {
    final exec = await ref.read(claudeExecutableProvider.future);
    if (exec == null) {
      if (mounted) {
        setState(() {
          _error = '未检测到 claude CLI，请在设置中配置路径。';
          _state = _PerfState.error;
        });
      }
      return;
    }
    final model = ref.read(activeModelProvider);
    final analyzer = PerformanceAiAnalyzer(claudeExecutable: exec, model: model);

    setState(() {
      _state = _PerfState.analyzing;
      _report = null;
      _error = null;
      _tools.clear();
    });

    try {
      final report = await analyzer.analyze(
        project: widget.project,
        onTool: (line) {
          _tools.insert(0, line);
          if (_tools.length > 12) _tools.removeLast();
          if (mounted) setState(() {});
        },
      );
      if (mounted) {
        setState(() {
          _report = report;
          _state = _PerfState.done;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _state = _PerfState.error;
        });
      }
    }
  }

  // ── 导出性能分析报告（Markdown）─────────────────────────────────────────────

  Future<void> _exportReport() async {
    final report = _report;
    if (report == null) return;
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出性能分析报告',
      fileName: '性能分析报告-${widget.project.name}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
      lockParentWindow: true,
    );
    if (path == null) return; // 用户取消
    try {
      await File(path).writeAsString(_buildReport(report));
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

  String _buildReport(PerformanceReport r) {
    final buf = StringBuffer();
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final ts = '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}';
    buf.writeln('# 性能分析报告 · ${widget.project.name}');
    buf.writeln();
    buf.writeln('> 生成时间：$ts');
    buf.writeln();
    buf.writeln('## 整体评估');
    buf.writeln('- 健康度：${r.overall}');
    buf.writeln('- ${r.summary.isEmpty ? "（无）" : r.summary}');
    buf.writeln();
    buf.writeln('## 性能问题（${r.issues.length}）');
    if (r.issues.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (var i = 0; i < r.issues.length; i++) {
        final e = r.issues[i];
        final loc = e.file.isEmpty ? '未知位置' : (e.line == null ? e.file : '${e.file}:${e.line}');
        buf.writeln();
        buf.writeln('### ${i + 1}. ${_cell(e.title)}');
        buf.writeln();
        buf.writeln('- 类别：${_cell(e.category)}');
        buf.writeln('- 严重度：${_cell(e.severity)} · 影响：${_cell(e.impact)}');
        buf.writeln('- 位置：${_cell(loc)}');
        if (e.description.isNotEmpty) {
          buf.writeln();
          buf.writeln('**问题描述**');
          buf.writeln();
          buf.writeln(e.description);
        }
        if (e.suggestion.isNotEmpty) {
          buf.writeln();
          buf.writeln('**优化建议**');
          buf.writeln();
          buf.writeln(e.suggestion);
        }
      }
    }
    buf.writeln();
    buf.writeln('## 系统性优化建议');
    if (r.suggestions.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (final s in r.suggestions) {
        buf.writeln('- ${_cell(s)}');
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
    final busy = _state == _PerfState.analyzing;
    final canExport = _state == _PerfState.done && _report != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      child: Row(children: [
        const Icon(Icons.speed_outlined, size: 18),
        const SizedBox(width: 8),
        Text('性能分析', style: Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        FilledButton.icon(
          onPressed: busy ? null : _runAi,
          icon: busy
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text(busy
              ? 'AI 分析中…'
              : (_state == _PerfState.done ? '重新分析' : 'AI 分析性能')),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.download_outlined, size: 18),
          tooltip: '导出性能报告',
          onPressed: canExport ? _exportReport : null,
        ),
      ]),
    );
  }

  Widget _body(BuildContext context, ColorScheme cs) {
    switch (_state) {
      case _PerfState.idle:
        return _center(cs, Icons.speed_outlined, '点击「AI 分析性能」，识别性能瓶颈');
      case _PerfState.analyzing:
        return _analyzingView(context, cs);
      case _PerfState.done:
        return _resultView(context, cs, _report!);
      case _PerfState.error:
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
          const Text('AI 正在阅读项目代码、分析性能…',
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

  Widget _resultView(BuildContext context, ColorScheme cs, PerformanceReport report) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: PerformanceReportView(report: report),
        ),
      ),
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
