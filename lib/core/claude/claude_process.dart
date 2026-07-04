import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

import 'claude_event.dart';

/// 与本机 `claude` CLI 子进程交互的封装。
///
/// 使用 stream-json 双向协议：
/// - 启动：`claude --input-format stream-json --output-format stream-json --verbose
///   [--resume <sessionId>] [--permission-mode <mode>]`
/// - 输入：每行一个 user message JSON
/// - 输出：每行一个事件 JSON（system / assistant / user / result / stream_event）
class ClaudeProcess {
  ClaudeProcess({Logger? logger, this.claudeExecutable = 'claude'})
    : _logger = logger ?? Logger();

  final Logger _logger;
  final String claudeExecutable;

  Process? _process;
  String? _sessionId;
  String? _cwd;
  bool _closed = false;

  final _eventController = StreamController<ClaudeEvent>.broadcast();
  final _stderrController = StreamController<String>.broadcast();
  final _doneCompleter = Completer<void>();

  Stream<ClaudeEvent> get events => _eventController.stream;

  Stream<String> get stderr => _stderrController.stream;

  Future<void> get done => _doneCompleter.future;

  String? get sessionId => _sessionId;

  String? get cwd => _cwd;

  bool get isRunning => _process != null && !_closed;

  /// 启动子进程。
  Future<void> start({
    required String workingDirectory,
    String? resumeSessionId,
    String permissionMode = 'default',
    String? model,
    Map<String, String>? environment,
  }) async {
    if (isRunning) {
      throw StateError('ClaudeProcess already running');
    }

    final args = <String>[
      '--input-format',
      'stream-json',
      '--output-format',
      'stream-json',
      '--verbose',
      '--permission-mode',
      permissionMode,
      if (model != null && model != 'default') ...['--model', model],
      if (resumeSessionId != null) ...['--resume', resumeSessionId],
    ];

    _logger.i(
      'Spawning claude: $claudeExecutable ${args.join(" ")} (cwd=$workingDirectory)',
    );

    _process = await Process.start(
      claudeExecutable,
      args,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: Platform.isWindows,
    );
    _cwd = workingDirectory;

    _wireStdout();
    _wireStderr();
    _process!.exitCode.then(_handleExit);
  }

  void _wireStdout() {
    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.isEmpty) return;
            try {
              final event = ClaudeEvent.fromRawJson(line);
              if (event is ClaudeSystemEvent && event.sessionId != null) {
                _sessionId = event.sessionId;
              }
              _eventController.add(event);
            } catch (e, st) {
              _logger.w('Failed to parse claude stdout line: $line\n$e\n$st');
            }
          },
          onError: (Object e) => _logger.w('stdout stream error: $e'),
          onDone: () => _logger.i('claude stdout closed'),
        );
  }

  void _wireStderr() {
    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.isEmpty) return;
          _stderrController.add(line);
          _logger.w('claude stderr: $line');
        }, onError: (Object e) => _logger.w('stderr stream error: $e'));
  }

  /// 发送一条用户消息。
  Future<void> send(String text) async {
    final proc = _process;
    if (proc == null || _closed) {
      throw StateError('ClaudeProcess not running');
    }
    final payload = jsonEncode({
      'type': 'user',
      'message': {'role': 'user', 'content': text},
    });
    _logger.d('claude stdin <- $payload');
    proc.stdin.writeln(payload);
    await proc.stdin.flush();
  }

  /// 中断当前回合（等价于在终端按 Ctrl+C）。
  Future<void> interrupt() async {
    final proc = _process;
    if (proc == null) return;
    final pid = proc.pid;
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
      } else {
        Process.killPid(pid, ProcessSignal.sigint);
      }
    } catch (e) {
      _logger.w('interrupt failed: $e');
    }
  }

  void _handleExit(int code) {
    if (_closed) return;
    _closed = true;
    _logger.i('claude exited with code $code');
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
    _eventController.close();
    _stderrController.close();
  }

  Future<void> dispose() async {
    final proc = _process;
    if (proc == null) return;
    try {
      await interrupt();
    } catch (_) {}
    try {
      await proc.stdin.close();
    } catch (_) {}
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    if (!_eventController.isClosed) _eventController.close();
    if (!_stderrController.isClosed) _stderrController.close();
    _process = null;
  }
}
