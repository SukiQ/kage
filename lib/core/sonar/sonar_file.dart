import 'dart:io';

import 'package:path/path.dart' as p;

import 'sonar_prompt.dart';
import 'sonar_report.dart';

/// issue 唯一标识（用于忽略去重）。
String issueKey(SonarIssue i) => '${i.component}:${i.line ?? 0}:${i.rule}';

/// SonarQube component key → 本地绝对路径（project.path + 相对路径）。
String localPathOf(SonarIssue issue, String projectKey, String projectPath) {
  final rel = shortComponent(issue.component, projectKey);
  return p.join(projectPath, rel);
}

/// 读取问题行前后各 3 行，带行号 + 问题行标记（▶）。
/// 文件不存在/越界返回 null；无行号时返回文件前 12 行。
Future<String?> readSnippet(String localPath, int? line) async {
  final f = File(localPath);
  if (!await f.exists()) return null;
  final lines = await f.readAsLines();
  if (lines.isEmpty) return '';
  int start;
  int end;
  if (line == null || line < 1) {
    start = 1;
    end = lines.length < 12 ? lines.length : 12;
  } else {
    start = (line - 3).clamp(1, lines.length);
    end = (line + 3).clamp(1, lines.length);
  }
  final buf = StringBuffer();
  for (var n = start; n <= end; n++) {
    final marker = n == line ? '▶' : ' ';
    buf.writeln('$marker $n\t${lines[n - 1]}');
  }
  return buf.toString().trimRight();
}

/// 在 Windows 资源管理器中定位文件（选中）或打开目录。
Future<void> openInExplorer(String path) async {
  final norm = path.replaceAll('/', r'\');
  try {
    if (Platform.isWindows) {
      if (await File(norm).exists()) {
        await Process.run('explorer.exe', ['/select,$norm']);
      } else if (await Directory(norm).exists()) {
        await Process.run('explorer.exe', [norm]);
      }
    }
  } catch (_) {}
}
