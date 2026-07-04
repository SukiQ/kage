import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/chat_session.dart';

/// 会话仓库：索引（meta）放在 sessions.json，每条会话的消息存为独立 JSON 文件。
class SessionRepository {
  SessionRepository._(this._indexFile, this._msgsDir);

  final File _indexFile;
  final Directory _msgsDir;
  List<ChatSessionMeta> _cache = [];

  static Future<SessionRepository> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'Kage', 'sessions'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final indexFile = File(p.join(dir.path, 'index.json'));
    if (!indexFile.existsSync()) indexFile.writeAsStringSync('[]');
    final msgsDir = Directory(p.join(dir.path, 'messages'));
    if (!msgsDir.existsSync()) msgsDir.createSync(recursive: true);
    final repo = SessionRepository._(indexFile, msgsDir);
    await repo._loadIndex();
    return repo;
  }

  Future<void> _loadIndex() async {
    try {
      final raw = await _indexFile.readAsString();
      final list = jsonDecode(raw) as List;
      _cache = list
          .map((e) => ChatSessionMeta.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cache = [];
    }
  }

  Future<void> _persistIndex() async {
    final json = jsonEncode(_cache.map((e) => e.toJson()).toList());
    await _indexFile.writeAsString(json);
  }

  List<ChatSessionMeta> all() => List.unmodifiable(_cache);

  List<ChatSessionMeta> forProject(String projectId) =>
      _cache.where((s) => s.projectId == projectId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<ChatSessionMeta> start({
    required String projectId,
    String title = '新会话',
  }) async {
    final now = DateTime.now();
    final meta = ChatSessionMeta(
      id: _uuid(),
      projectId: projectId,
      claudeSessionId: null,
      title: title,
      createdAt: now,
      updatedAt: now,
    );
    _cache.add(meta);
    await _persistIndex();
    await _writeMessages(meta.id, const []);
    return meta;
  }

  Future<void> updateMeta(ChatSessionMeta meta) async {
    final i = _cache.indexWhere((s) => s.id == meta.id);
    if (i >= 0) _cache[i] = meta;
    await _persistIndex();
  }

  Future<void> saveMessages(String sessionId, List<StoredMessage> msgs) async {
    await _writeMessages(sessionId, msgs);
    final i = _cache.indexWhere((s) => s.id == sessionId);
    if (i >= 0) {
      _cache[i] = _cache[i].copyWith(updatedAt: DateTime.now());
      await _persistIndex();
    }
  }

  Future<List<StoredMessage>> loadMessages(String sessionId) async {
    final f = File(p.join(_msgsDir.path, '$sessionId.json'));
    if (!f.existsSync()) return const [];
    try {
      final raw = await f.readAsString();
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => StoredMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> delete(String sessionId) async {
    _cache.removeWhere((s) => s.id == sessionId);
    await _persistIndex();
    final f = File(p.join(_msgsDir.path, '$sessionId.json'));
    if (f.existsSync()) await f.delete();
  }

  Future<void> _writeMessages(
    String sessionId,
    List<StoredMessage> msgs,
  ) async {
    final f = File(p.join(_msgsDir.path, '$sessionId.json'));
    await f.writeAsString(jsonEncode(msgs.map((e) => e.toJson()).toList()));
  }

  String _uuid() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 's_$now';
  }
}
