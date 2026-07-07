import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/analysis/analysis_dimension.dart';
import '../core/claude/claude_detector.dart';
import '../core/scanners/scan_result.dart';
import '../core/scanners/scanner.dart';
import '../core/scanners/sonarqube_scanner.dart';
import '../core/storage/settings_service.dart';
import '../data/models/issue_record.dart';
import '../data/models/project.dart';
import '../data/repositories/issue_repository.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/rule_note_repository.dart';

final loggerProvider = Provider<Logger>(
  (_) => Logger(printer: SimplePrinter()),
);

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  return SettingsService.create();
});

final claudeDetectorProvider = Provider<ClaudeDetector>((ref) {
  return ClaudeDetector();
});

/// 当前激活项目（全局）
final activeProjectProvider = StateProvider<KageProject?>((ref) => null);

/// 当前选中的分析维度
final activeDimensionProvider = StateProvider<AnalysisDimension>(
  (ref) => AnalysisDimension.codeQuality,
);

/// AI 会话使用的模型（claude CLI --model 参数值，如 default/sonnet/opus/haiku）
final activeModelProvider = StateProvider<String>((ref) => 'default');

/// 最近一次统一扫描结果
final activeScanResultProvider = StateProvider<ScanResult?>((ref) => null);

/// 已忽略的 issue 标识集合（本次会话内存）
final ignoredIssuesProvider = StateProvider<Set<String>>((ref) => {});

/// 当前项目已加载的 Issue 生命周期记录（内存缓存）
final issueRecordsProvider = StateProvider<List<IssueRecord>>((ref) => const []);

// ── 仓库 ────────────────────────────────────────────────────────────────────

final projectRepositoryProvider = FutureProvider<ProjectRepository>((ref) async {
  return ProjectRepository.create();
});

final issueRepositoryProvider = FutureProvider<IssueRepository>((ref) async {
  return IssueRepository.create();
});

/// 全局 rule→修复附言记忆
final ruleNoteRepositoryProvider = FutureProvider<RuleNoteRepository>((ref) async {
  return RuleNoteRepository.create();
});

// ── 扫描器 ──────────────────────────────────────────────────────────────────

final activeScannerProvider = FutureProvider<Scanner>((ref) async {
  final settings = await ref.watch(settingsServiceProvider.future);
  return SonarQubeScanner(settings);
});

final claudeExecutableProvider = FutureProvider<String?>((ref) async {
  final settings = await ref.watch(settingsServiceProvider.future);
  final fromSettings = settings.claudeExecutable;
  if (fromSettings != null && fromSettings.isNotEmpty) return fromSettings;
  final detector = ref.watch(claudeDetectorProvider);
  return detector.detect();
});

// ── 主题 ─────────────────────────────────────────────────────────────────────

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  Future<void> init() async {
    final s = await ref.read(settingsServiceProvider.future);
    state = switch (s.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    final s = await ref.read(settingsServiceProvider.future);
    await s.setThemeMode(mode.name);
  }
}
