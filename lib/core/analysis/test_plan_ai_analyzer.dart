import 'dart:async';

import '../claude/claude_event.dart';
import '../claude/claude_process.dart';
import '../../data/models/project.dart';
import 'ai_json.dart';
import 'analysis_prompt.dart';
import 'test_plan_report.dart';

/// 一次性 AI 测试计划分析：让 Claude 阅读项目代码和现有测试，输出测试计划 JSON。
///
/// 可靠性要点（与 ArchitectureAiAnalyzer / PerformanceAiAnalyzer 一致）：
/// - 用 `--dangerously-skip-permissions` 跳过工具权限确认。
/// - **等待 result 事件而非进程退出**：stream-json 单轮响应后不退出进程。
/// - 进程异常退出作为兜底，配合 stderr 报错便于诊断。
/// - 监听工具调用（Read/Glob/Grep）回调，进度可见。
/// - JSON 解析容错（[AiJson.decodeLoose]）。
class TestPlanAiAnalyzer {
  TestPlanAiAnalyzer({required this.claudeExecutable, this.model = 'default'});

  final String claudeExecutable;
  final String model;

  Future<TestPlanReport> analyze({
    required KageProject project,
    void Function(String chunk)? onProgress,
    void Function(String toolLine)? onTool,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final proc = ClaudeProcess(claudeExecutable: claudeExecutable);
    await proc.start(
      workingDirectory: project.path,
      bypassPermissions: true,
      model: model,
    );

    final buf = StringBuffer();
    final stderrBuf = StringBuffer();
    String? error;
    StreamSubscription<ClaudeEvent>? sub;
    StreamSubscription<String>? stderrSub;
    final doneCompleter = Completer<void>();

    try {
      sub = proc.events.listen((event) {
        if (event is ClaudeAssistantEvent) {
          for (final b in event.content) {
            if (b is ClaudeTextBlock && b.text.isNotEmpty) {
              buf.write(b.text);
              onProgress?.call(b.text);
            } else if (b is ClaudeToolUseBlock) {
              final line = _describeTool(b);
              if (line.isNotEmpty) onTool?.call(line);
            }
          }
        } else if (event is ClaudeResultEvent) {
          if (event.isError) error = event.result;
          if (!doneCompleter.isCompleted) doneCompleter.complete();
        }
      });
      stderrSub = proc.stderr.listen((line) {
        if (line.trim().isNotEmpty) stderrBuf.writeln(line);
      });

      proc.done.then((_) {
        if (!doneCompleter.isCompleted) doneCompleter.complete();
      });

      final prompt = AnalysisPrompt.buildTestPlanMessage(
        projectName: project.name,
        projectPath: project.path,
      );
      await proc.send(prompt);
      await doneCompleter.future.timeout(timeout, onTimeout: () {
        throw TimeoutException('AI 测试规划超时（${timeout.inMinutes} 分钟）。');
      });
    } finally {
      await sub?.cancel();
      await stderrSub?.cancel();
      await proc.dispose();
    }

    final text = buf.toString().trim();
    final stderr = stderrBuf.toString().trim();

    if (error != null) {
      throw Exception('AI 分析失败：$error${stderr.isEmpty ? '' : '\nCLI 输出：$stderr'}');
    }
    if (text.isEmpty) {
      throw Exception(stderr.isEmpty
          ? 'Claude CLI 未返回任何内容（可能启动失败或被中断）。'
          : 'Claude CLI 异常退出：\n$stderr');
    }

    final decoded = AiJson.decodeLoose(text);
    if (decoded == null) {
      final preview = text.length > 400 ? '${text.substring(0, 400)}…' : text;
      throw Exception('无法从 AI 输出中解析测试计划 JSON。\n原始输出片段：\n$preview');
    }
    return TestPlanReport.fromJson(decoded);
  }

  /// 把工具调用格式化为进度行，如 "Read · lib/app/app.dart"。
  String _describeTool(ClaudeToolUseBlock b) {
    final name = b.name ?? '工具';
    final input = b.input;
    if (input is Map) {
      final fp = input['file_path'] ?? input['path'] ?? input['pattern'] ?? input['command'];
      if (fp is String && fp.isNotEmpty) return '$name · $fp';
    }
    return name;
  }
}
