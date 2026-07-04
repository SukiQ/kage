import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 检测本机 `claude` CLI 是否可用。
class ClaudeDetector {
  ClaudeDetector({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  /// 探测 claude 可执行文件路径，未找到返回 null。
  Future<String?> detect() async {
    final candidates = <String>['claude'];
    final home = _homeDir();
    if (home != null) {
      if (Platform.isWindows) {
        candidates.add(p.join(home, '.claude', 'local', 'claude.exe'));
        candidates.add(p.join(home, '.claude', 'local', 'claude.cmd'));
      } else {
        candidates.add(p.join(home, '.claude', 'local', 'claude'));
      }
    }

    for (final c in candidates) {
      try {
        final result = await Process.run(c, [
          '--version',
        ], runInShell: Platform.isWindows);
        if (result.exitCode == 0) {
          _logger.i(
            'claude detected: $c (${(result.stdout as String).trim()})',
          );
          return c;
        }
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  /// 读取 ~/.claude/settings.json（含 API Key 等配置）。
  Future<File?> settingsFile() async {
    final home = _homeDir();
    if (home == null) return null;
    final f = File(p.join(home, '.claude', 'settings.json'));
    return f.existsSync() ? f : null;
  }

  /// 用户主目录。
  String? _homeDir() {
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'];
    }
    return Platform.environment['HOME'];
  }

  /// 应用数据目录（用于存储 Kage 自身的配置/会话）。
  Future<Directory> appDataDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'Kage'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }
}
