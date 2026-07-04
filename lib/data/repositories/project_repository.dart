import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/project.dart';

/// 项目（工作目录）仓库，本地 JSON 文件持久化。
class ProjectRepository {
  ProjectRepository._(this._file);

  final File _file;
  final _uuid = const Uuid();
  List<KageProject> _cache = [];

  static Future<ProjectRepository> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'Kage'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'projects.json'));
    if (!file.existsSync()) file.writeAsStringSync('[]');
    final repo = ProjectRepository._(file);
    await repo._load();
    return repo;
  }

  Future<void> _load() async {
    try {
      final raw = await _file.readAsString();
      final list = jsonDecode(raw) as List;
      _cache = list
          .map((e) => KageProject.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cache = [];
    }
  }

  Future<void> _persist() async {
    final json = jsonEncode(_cache.map((e) => e.toJson()).toList());
    await _file.writeAsString(json);
  }

  List<KageProject> get all => List.unmodifiable(_cache);

  KageProject? findById(String id) {
    for (final p in _cache) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<KageProject> add({
    required String name,
    required String path,
    String? sonarProjectKey,
  }) async {
    final project = KageProject(
      id: _uuid.v4(),
      name: name,
      path: path,
      sonarProjectKey: sonarProjectKey,
    );
    _cache.add(project);
    await _persist();
    return project;
  }

  Future<void> update(KageProject project) async {
    final i = _cache.indexWhere((p) => p.id == project.id);
    if (i >= 0) _cache[i] = project;
    await _persist();
  }

  Future<void> delete(String id) async {
    _cache.removeWhere((p) => p.id == id);
    await _persist();
  }
}
