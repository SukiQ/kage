import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Issue 修复附言仓库：按错误码（rule）全局共享记忆。
/// 用户对某类问题（rule）填写的修复附言，下次遇到相同 rule 的问题时自动复用。
class RuleNoteRepository {
  RuleNoteRepository._(this._file);

  final File _file;
  Map<String, String> _cache = {};

  static Future<RuleNoteRepository> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'Kage'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'rule_notes.json'));
    if (!file.existsSync()) file.writeAsStringSync('{}');
    final repo = RuleNoteRepository._(file);
    await repo._load();
    return repo;
  }

  Future<void> _load() async {
    try {
      final raw = await _file.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache = map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      _cache = {};
    }
  }

  Future<void> _persist() async {
    await _file.writeAsString(jsonEncode(_cache));
  }

  /// 读取某 rule 的附言，未设置返回 null。
  String? getNote(String rule) => _cache[rule];

  /// 全部 rule→附言映射（只读）。
  Map<String, String> get all => Map.unmodifiable(_cache);

  /// 设置某 rule 的附言；note 为空则删除该 rule 的记录。
  Future<void> setNote(String rule, String? note) async {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      if (_cache.containsKey(rule)) {
        _cache.remove(rule);
        await _persist();
      }
      return;
    }
    if (_cache[rule] == trimmed) return;
    _cache[rule] = trimmed;
    await _persist();
  }
}
