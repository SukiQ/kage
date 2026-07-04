import 'dart:io';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

import '../models/skill.dart';

/// 扫描 ~/.claude/skills/ 下每个子目录的 SKILL.md，解析 frontmatter。
class SkillsRepository {
  SkillsRepository({Logger? logger}) : _logger = logger ?? Logger();

  final Logger _logger;

  Future<List<KageSkill>> scan() async {
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (home == null) return const [];

    final dir = Directory(p.join(home, '.claude', 'skills'));
    if (!dir.existsSync()) return const [];

    final skills = <KageSkill>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final skillMd = File(p.join(entry.path, 'SKILL.md'));
      if (!skillMd.existsSync()) continue;
      try {
        final raw = await skillMd.readAsString();
        final parsed = _parseFrontmatter(raw);
        if (parsed == null) continue;
        skills.add(
          KageSkill.fromFrontmatter(
            parsed['name'] ?? p.basename(entry.path),
            parsed['description'] ?? '',
            source: SkillSource.user,
          ),
        );
      } catch (e) {
        _logger.w('Failed to parse SKILL.md in ${entry.path}: $e');
      }
    }
    return skills;
  }

  Map<String, String>? _parseFrontmatter(String raw) {
    if (!raw.startsWith('---')) return null;
    final end = raw.indexOf('\n---', 3);
    if (end < 0) return null;
    final block = raw.substring(3, end).trim();
    final map = <String, String>{};
    for (final line in block.split('\n')) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      final key = line.substring(0, i).trim();
      var value = line.substring(i + 1).trim();
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      map[key] = value;
    }
    return map;
  }
}
