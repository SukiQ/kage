import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置服务：负责 Kage 自身的 KV 配置（当前项目、API Key 提示、主题等）。
class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _kClaudeExecutable = 'claudeExecutable';
  static const _kActiveProjectId = 'activeProjectId';
  static const _kOnboarded = 'onboarded';
  static const _kThemeMode = 'themeMode'; // light | dark | system
  static const _kSonarHost = 'sonarHost';
  static const _kSonarToken = 'sonarToken';

  static Future<SettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  String? get claudeExecutable => _prefs.getString(_kClaudeExecutable);

  Future<void> setClaudeExecutable(String? value) async {
    if (value == null) {
      await _prefs.remove(_kClaudeExecutable);
    } else {
      await _prefs.setString(_kClaudeExecutable, value);
    }
  }

  String? get activeProjectId => _prefs.getString(_kActiveProjectId);

  Future<void> setActiveProjectId(String? value) async {
    if (value == null) {
      await _prefs.remove(_kActiveProjectId);
    } else {
      await _prefs.setString(_kActiveProjectId, value);
    }
  }

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;

  Future<void> setOnboarded(bool v) => _prefs.setBool(_kOnboarded, v);

  String get themeMode => _prefs.getString(_kThemeMode) ?? 'system';

  Future<void> setThemeMode(String v) => _prefs.setString(_kThemeMode, v);

  String? get sonarHost => _prefs.getString(_kSonarHost);

  Future<void> setSonarHost(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_kSonarHost);
    } else {
      await _prefs.setString(_kSonarHost, value);
    }
  }

  String? get sonarToken => _prefs.getString(_kSonarToken);

  Future<void> setSonarToken(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(_kSonarToken);
    } else {
      await _prefs.setString(_kSonarToken, value);
    }
  }
}

/// 把 API Key 写入 ~/.claude/settings.json，让 claude CLI 自动读取。
Future<void> writeClaudeApiKey(String apiKey) async {
  final home = Platform.isWindows
      ? Platform.environment['USERPROFILE']
      : Platform.environment['HOME'];
  if (home == null) throw StateError('Cannot resolve user home directory');

  final dir = Directory(p.join(home, '.claude'));
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final file = File(p.join(dir.path, 'settings.json'));
  Map<String, dynamic> json = {};
  if (file.existsSync()) {
    try {
      json = (jsonDecode(file.readAsStringSync()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      json = {};
    }
  }

  final env = (json['env'] as Map?)?.cast<String, dynamic>() ?? {};
  env['ANTHROPIC_API_KEY'] = apiKey;
  json['env'] = env;

  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
}
