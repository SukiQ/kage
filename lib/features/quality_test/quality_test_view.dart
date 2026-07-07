import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/test_code_generator.dart';
import '../../core/analysis/test_plan_ai_analyzer.dart';
import '../../core/analysis/test_plan_report.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/test_plan_report_view.dart';
import '../../shared/widgets/test_result_view.dart';

enum _QTState { idle, planning, donePlanning, testing, doneTesting, error }

class QualityTestView extends ConsumerStatefulWidget {
  const QualityTestView({super.key, required this.project});
  final KageProject project;

  @override
  ConsumerState<QualityTestView> createState() => _QualityTestViewState();
}

class _QualityTestViewState extends ConsumerState<QualityTestView> {
  _QTState _state = _QTState.idle;
  TestPlanReport? _report;
  TestExecutionResult? _testResult;
  String? _interpretation;
  String? _error;
  final _tools = <String>[];
  final _testOutput = <String>[];
  final Map<String, CaseRunStatus> _caseRuns = {};
  final Map<String, CaseGenStatus> _caseGens = {};

  @override
  void didUpdateWidget(covariant QualityTestView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id ||
        oldWidget.project.path != widget.project.path) {
      _report = null;
      _testResult = null;
      _interpretation = null;
      _error = null;
      _tools.clear();
      _testOutput.clear();
      _caseRuns.clear();
      _caseGens.clear();
      _state = _QTState.idle;
    }
  }

  // ── AI 测试规划 ────────────────────────────────────────────────────────────

  Future<void> _runAi() async {
    final exec = await ref.read(claudeExecutableProvider.future);
    if (exec == null) {
      if (mounted) {
        setState(() {
          _error = '未检测到 claude CLI，请在设置中配置路径。';
          _state = _QTState.error;
        });
      }
      return;
    }
    final model = ref.read(activeModelProvider);
    final analyzer = TestPlanAiAnalyzer(claudeExecutable: exec, model: model);

    setState(() {
      _state = _QTState.planning;
      _report = null;
      _testResult = null;
      _interpretation = null;
      _error = null;
      _tools.clear();
      _caseRuns.clear();
      _caseGens.clear();
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
          _state = _QTState.donePlanning;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _state = _QTState.error;
        });
      }
    }
  }

  // ── 执行测试 + AI 解读 ──────────────────────────────────────────────────────

  Future<void> _runTests() async {
    final exec = await ref.read(claudeExecutableProvider.future);
    if (exec == null) {
      if (mounted) {
        setState(() {
          _error = '未检测到 claude CLI，请在设置中配置路径。';
          _state = _QTState.error;
        });
      }
      return;
    }
    setState(() {
      _state = _QTState.testing;
      _testResult = null;
      _interpretation = null;
      _error = null;
      _testOutput.clear();
    });
    try {
      final model = ref.read(activeModelProvider);
      final runner = AiTestRunner(claudeExecutable: exec, model: model);
      final result = await runner.run(
        projectPath: widget.project.path,
        projectName: widget.project.name,
        testTarget: '',
        onOutput: (line) {
          _testOutput.insert(0, line);
          if (_testOutput.length > 30) _testOutput.removeLast();
          if (mounted) setState(() {});
        },
      );
      if (mounted) {
        setState(() {
          _testResult = result;
          _interpretation = null;
          _state = _QTState.doneTesting;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _state = _QTState.error;
        });
      }
    }
  }

  // ── 导出 ────────────────────────────────────────────────────────────────────

  // ── 单个用例执行测试（委托 Claude 运行）──────────────────────────────────────

  Future<void> _runSingleTest(RecommendedTestCase c) async {
    final key = '${c.module}::${c.scenario}';
    final exec = await ref.read(claudeExecutableProvider.future);
    if (exec == null) {
      if (mounted) {
        setState(() => _caseRuns[key] = const CaseRunStatus(
          state: CaseRunState.error,
          error: '未检测到 claude CLI，请在设置中配置路径。',
        ));
      }
      return;
    }
    // 测试目标：优先用生成时写入的测试文件路径，否则让 AI 按 module 自行定位。
    final target = _caseGens[key]?.filePath ?? c.module;
    setState(() => _caseRuns[key] = const CaseRunStatus(state: CaseRunState.running));
    try {
      final model = ref.read(activeModelProvider);
      final runner = AiTestRunner(claudeExecutable: exec, model: model);
      final result = await runner.run(
        projectPath: widget.project.path,
        projectName: widget.project.name,
        testTarget: target,
      );
      if (mounted) {
        setState(() => _caseRuns[key] = CaseRunStatus(state: CaseRunState.done, result: result));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _caseRuns[key] = CaseRunStatus(state: CaseRunState.error, error: e.toString()));
      }
    }
  }

  // ── 单个用例生成测试代码（委托 Claude 写入项目）──────────────────────────────

  Future<void> _genTestCode(RecommendedTestCase c) async {
    final key = '${c.module}::${c.scenario}';
    final exec = await ref.read(claudeExecutableProvider.future);
    if (exec == null) {
      if (mounted) {
        setState(() => _caseGens[key] = const CaseGenStatus(
          state: CaseGenState.error,
          error: '未检测到 claude CLI，请在设置中配置路径。',
        ));
      }
      return;
    }
    setState(() => _caseGens[key] = const CaseGenStatus(state: CaseGenState.generating));
    try {
      final model = ref.read(activeModelProvider);
      final gen = TestCodeGenerator(claudeExecutable: exec, model: model);
      final result = await gen.generate(
        projectPath: widget.project.path,
        projectName: widget.project.name,
        testCase: c,
      );
      if (mounted) {
        setState(() => _caseGens[key] = CaseGenStatus(
          state: CaseGenState.done,
          code: result.code,
          filePath: result.files.isEmpty ? null : result.files.first,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _caseGens[key] = CaseGenStatus(state: CaseGenState.error, error: e.toString()));
      }
    }
  }

  Future<void> _export(String title, String fileName, String content) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: title,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['md'],
      lockParentWindow: true,
    );
    if (path == null) return;
    try {
      await File(path).writeAsString(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出：$path'), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  Future<void> _exportPlan() async {
    final r = _report;
    if (r == null) return;
    await _export('导出测试计划', '测试计划-${widget.project.name}.md', _buildPlanReport(r));
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
  }

  String _cell(String s) => s.replaceAll('|', '\\|').replaceAll('\n', ' ');

  String _buildPlanReport(TestPlanReport r) {
    final buf = StringBuffer();
    buf.writeln('# 测试计划 · ${widget.project.name}');
    buf.writeln();
    buf.writeln('> 生成时间：${_stamp()}');
    buf.writeln();
    final cov = (r.coverageGaps.overallCoverage * 100).clamp(0, 100);
    buf.writeln('## 整体评估');
    buf.writeln('- 覆盖率估算：${cov.toStringAsFixed(0)}%');
    buf.writeln('- ${r.summary.isEmpty ? "（无）" : r.summary}');
    buf.writeln();
    if (r.coverageGaps.highRiskModules.isNotEmpty) {
      buf.writeln('## 高风险模块');
      for (final m in r.coverageGaps.highRiskModules) {
        buf.writeln('- ${_cell(m)}');
      }
      buf.writeln();
    }
    buf.writeln('## 推荐测试用例（${r.recommendedCases.length}）');
    if (r.recommendedCases.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (var i = 0; i < r.recommendedCases.length; i++) {
        final c = r.recommendedCases[i];
        buf.writeln();
        buf.writeln('### ${i + 1}. ${_cell(c.scenario)}');
        buf.writeln();
        buf.writeln('- 模块：${_cell(c.module)}');
        buf.writeln('- 优先级：${_cell(c.priority)} · 类别：${_cell(c.category)} · 类型：${_cell(c.testType)}');
        if (c.description.isNotEmpty) {
          buf.writeln();
          buf.writeln('**测试描述**');
          buf.writeln();
          buf.writeln(c.description);
        }
        if (c.whyImportant.isNotEmpty) {
          buf.writeln();
          buf.writeln('**重要性**');
          buf.writeln();
          buf.writeln(c.whyImportant);
        }
      }
    }
    buf.writeln();
    buf.writeln('## 系统性测试建议');
    if (r.suggestions.isEmpty) {
      buf.writeln('（无）');
    } else {
      for (final s in r.suggestions) {
        buf.writeln('- ${_cell(s)}');
      }
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      _toolbar(context, cs),
      Expanded(child: _body(context, cs)),
    ]);
  }

  Widget _toolbar(BuildContext context, ColorScheme cs) {
    final planning = _state == _QTState.planning;
    final testing = _state == _QTState.testing;
    final busy = planning || testing;
    final hasPlan = _report != null;
    final hasResult = _testResult != null;
    final spin = const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant))),
      child: Row(children: [
        const Icon(Icons.science_outlined, size: 18),
        const SizedBox(width: 8),
        Text('质量测试', style: Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        FilledButton.icon(
          onPressed: busy ? null : _runAi,
          icon: planning ? spin : const Icon(Icons.auto_awesome_outlined, size: 16),
          label: Text(planning ? 'AI 规划中…' : (hasPlan ? '重新规划' : 'AI 规划测试')),
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
        if (hasPlan) ...[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: testing ? null : _runTests,
            icon: testing ? spin : const Icon(Icons.play_arrow_outlined, size: 16),
            label: Text(testing ? '执行中…' : (hasResult ? '重新执行测试' : '执行测试')),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.download_outlined, size: 18),
          tooltip: '导出测试计划',
          onPressed: hasPlan ? _exportPlan : null,
        ),
      ]),
    );
  }

  Widget _body(BuildContext context, ColorScheme cs) {
    switch (_state) {
      case _QTState.idle:
        return _center(cs, Icons.science_outlined, '点击「AI 规划测试」，推荐缺失的测试用例');
      case _QTState.planning:
        return _analyzingView(context, cs, 'AI 正在阅读项目代码和测试、规划测试用例…', _tools);
      case _QTState.donePlanning:
        return _scroll(_planSection(context, cs));
      case _QTState.testing:
        return _analyzingView(context, cs, '正在执行测试（flutter test / dart test）…', _testOutput);
      case _QTState.doneTesting:
        return _scroll(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, '测试计划'),
            _planSection(context, cs),
            const SizedBox(height: 20),
            _sectionTitle(context, '测试结果'),
            _resultSection(context, cs),
          ],
        ));
      case _QTState.error:
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _errorBanner(context, cs),
          ),
        );
    }
  }

  Widget _scroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 880), child: child)),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ]),
    );
  }

  Widget _planSection(BuildContext context, ColorScheme cs) => TestPlanReportView(
        report: _report!,
        caseRuns: _caseRuns,
        onRunTest: _runSingleTest,
        caseGens: _caseGens,
        onGenTest: _genTestCode,
      );

  Widget _resultSection(BuildContext context, ColorScheme cs) =>
      TestResultView(result: _testResult!, interpretation: _interpretation);

  Widget _center(ColorScheme cs, IconData icon, String text) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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

  Widget _analyzingView(BuildContext context, ColorScheme cs, String title, List<String> lines) {
    final current = lines.isEmpty ? '准备中…' : lines.first;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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

  Widget _errorBanner(BuildContext context, ColorScheme cs) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
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
            Text('操作失败', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.error)),
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
      ),
    );
  }
}
