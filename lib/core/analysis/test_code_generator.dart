import 'dart:async';
import 'dart:convert';

import '../claude/claude_event.dart';
import '../claude/claude_process.dart';
import 'analysis_prompt.dart';
import 'test_plan_report.dart';

/// AI 测试代码生成结果。
class GeneratedTest {
  const GeneratedTest({required this.code, this.files = const []});

  /// Claude 正文粘贴的完整代码（供 UI 预览）。
  final String code;

  /// 写入项目的测试文件相对路径（由 Write/Edit/MultiEdit 工具调用捕获）。
  final List<String> files;
}

/// AI 测试代码生成：让 Claude 阅读被测源码、按项目语言惯例用 Write 直接写入测试文件。
/// 语言无关（Java/Python/Dart 等通用）。返回正文代码 + 写入文件相对路径。
class TestCodeGenerator {
  TestCodeGenerator({required this.claudeExecutable, this.model = 'default'});

  final String claudeExecutable;
  final String model;

  Future<GeneratedTest> generate({
    required String projectPath,
    required String projectName,
    required RecommendedTestCase testCase,
    void Function(String chunk)? onProgress,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final proc = ClaudeProcess(claudeExecutable: claudeExecutable);
    await proc.start(
      workingDirectory: projectPath,
      bypassPermissions: true,
      model: model,
    );

    final buf = StringBuffer();
    final files = <String>[];
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
              final name = b.name ?? '';
              if (name == 'Write' || name == 'Edit' || name == 'MultiEdit') {
                final fp = _extractFilePath(b.input);
                if (fp != null) files.add(_toRelative(projectPath, fp));
              }
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

      await proc.send(AnalysisPrompt.buildTestCodeMessage(
        projectName: projectName,
        testCase: testCase,
      ));
      await doneCompleter.future.timeout(timeout, onTimeout: () {
        throw TimeoutException('AI 测试代码生成超时（${timeout.inMinutes} 分钟）。');
      });
    } finally {
      await sub?.cancel();
      await stderrSub?.cancel();
      await proc.dispose();
    }

    final text = buf.toString().trim();
    final stderr = stderrBuf.toString().trim();

    if (error != null) {
      throw Exception('AI 生成失败：$error${stderr.isEmpty ? '' : '\nCLI 输出：$stderr'}');
    }
    if (text.isEmpty && files.isEmpty) {
      throw Exception(stderr.isEmpty ? 'Claude CLI 未返回内容。' : 'Claude CLI 异常退出：\n$stderr');
    }
    return GeneratedTest(code: _stripFence(text), files: files);
  }

  /// 从 tool_use input 中提取 file_path（兼容 Write/Edit/MultiEdit）。
  String? _extractFilePath(dynamic input) {
    if (input is Map) {
      final fp = input['file_path'] ?? input['path'];
      if (fp is String && fp.isNotEmpty) return fp;
    }
    return null;
  }

  /// 把 Claude 报告的（可能绝对）路径转成相对项目根；已是相对则原样返回。
  String _toRelative(String projectPath, String fp) {
    var p = fp.replaceAll('\\', '/');
    final root = projectPath.replaceAll('\\', '/');
    if (p.startsWith('$root/')) p = p.substring(root.length + 1);
    return p;
  }

  /// 剥离 Markdown 代码围栏（```dart ... ```），取代码本体。
  String _stripFence(String text) {
    final m = RegExp(r'```(?:dart)?\s*([\s\S]*?)```').firstMatch(text);
    return (m?.group(1) ?? text).trim();
  }
}

/// AI 测试执行器：委托 Claude 识别构建工具并运行测试目标，按约定 JSON 返回结果。
class AiTestRunner {
  AiTestRunner({required this.claudeExecutable, this.model = 'default'});

  final String claudeExecutable;
  final String model;

  Future<TestExecutionResult> run({
    required String projectPath,
    required String projectName,
    required String testTarget,
    void Function(String line)? onOutput,
    Duration timeout = const Duration(minutes: 30),
  }) async {
    final proc = ClaudeProcess(claudeExecutable: claudeExecutable);
    await proc.start(
      workingDirectory: projectPath,
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
              onOutput?.call(b.text);
            }
          }
        } else if (event is ClaudeResultEvent) {
          if (event.isError) error = event.result;
          if (!doneCompleter.isCompleted) doneCompleter.complete();
        }
      });
      stderrSub = proc.stderr.listen((line) {
        if (line.trim().isNotEmpty) {
          stderrBuf.writeln(line);
          onOutput?.call(line);
        }
      });

      proc.done.then((_) {
        if (!doneCompleter.isCompleted) doneCompleter.complete();
      });

      await proc.send(AnalysisPrompt.buildTestRunMessage(
        projectName: projectName,
        testTarget: testTarget,
      ));
      await doneCompleter.future.timeout(timeout, onTimeout: () {
        throw TimeoutException('测试执行超时（${timeout.inMinutes} 分钟）。');
      });
    } finally {
      await sub?.cancel();
      await stderrSub?.cancel();
      await proc.dispose();
    }

    final text = buf.toString();
    final stderr = stderrBuf.toString().trim();
    if (error != null) {
      throw Exception('测试运行失败：$error${stderr.isEmpty ? '' : '\n$stderr'}');
    }
    return _parse(text, stderr);
  }

  /// 从 Claude 回复中解析约定 JSON；失败则降级为「未解析」结果（保留原文供查看）。
  TestExecutionResult _parse(String text, String stderr) {
    final json = _lastJsonObject(text);
    if (json != null) {
      try {
        final m = jsonDecode(json) as Map<String, dynamic>;
        final passed = (m['passed'] as num?)?.toInt() ?? 0;
        final failed = (m['failed'] as num?)?.toInt() ?? 0;
        final skipped = (m['skipped'] as num?)?.toInt() ?? 0;
        final success = m['success'] as bool? ?? (failed == 0);
        final failures = (m['failures'] as List? ?? [])
            .whereType<Map>()
            .map((e) => TestFailure(
                  name: e['name']?.toString() ?? '',
                  error: e['error']?.toString() ?? '',
                  stackTrace: '',
                ))
            .toList();
        return TestExecutionResult(
          total: passed + failed + skipped,
          passed: passed,
          failed: failed,
          skipped: skipped,
          duration: Duration.zero,
          failures: failures,
          success: success,
          rawOutput: text,
        );
      } catch (_) {
        // 解析失败走降级
      }
    }
    return TestExecutionResult(
      total: 0,
      passed: 0,
      failed: 0,
      skipped: 0,
      duration: Duration.zero,
      failures: const [],
      success: false,
      rawOutput: text.isEmpty ? stderr : text,
    );
  }

  /// 取文本中最后一个可成功解析的 `{ ... }` JSON 对象子串。
  String? _lastJsonObject(String text) {
    var start = text.lastIndexOf('{');
    while (start >= 0) {
      final candidate = text.substring(start);
      final end = candidate.lastIndexOf('}');
      if (end > 0) {
        final slice = candidate.substring(0, end + 1);
        try {
          jsonDecode(slice);
          return slice;
        } catch (_) {}
      }
      start = text.lastIndexOf('{', start - 1);
    }
    return null;
  }
}
