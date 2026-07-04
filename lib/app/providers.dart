import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../core/claude/claude_detector.dart';
import '../core/sonar/sonar_report.dart';
import '../core/storage/settings_service.dart';
import '../data/models/project.dart';
import '../data/models/prompt_template.dart';
import '../data/models/skill.dart';
import '../data/presets/preset_loader.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/session_repository.dart';
import '../data/repositories/skills_repository.dart';

final loggerProvider = Provider<Logger>(
  (_) => Logger(printer: SimplePrinter()),
);

final settingsServiceProvider = FutureProvider<SettingsService>((ref) async {
  return SettingsService.create();
});

final claudeDetectorProvider = Provider<ClaudeDetector>((ref) {
  return ClaudeDetector();
});

/// 当前激活项目（全局），由 HomeView 与 ChatView 共用。
final activeProjectProvider = StateProvider<KageProject?>((ref) => null);

/// 最近一次代码审查的 SonarQube 报告（审查后保留，供侧栏问题查看器使用）。
final reviewReportProvider = StateProvider<SonarReport?>((ref) => null);

/// 已忽略的 issue 标识集合（key = `component:line:rule`），从侧栏列表隐藏。
final ignoredIssuesProvider = StateProvider<Set<String>>((ref) => {});

final projectRepositoryProvider = FutureProvider<ProjectRepository>((
  ref,
) async {
  return ProjectRepository.create();
});

final sessionRepositoryProvider = FutureProvider<SessionRepository>((
  ref,
) async {
  return SessionRepository.create();
});

final templatesProvider = FutureProvider<List<PromptTemplate>>((ref) async {
  return PresetLoader.loadTemplates();
});

final skillsProvider = FutureProvider<List<KageSkill>>((ref) async {
  final repo = SkillsRepository();
  return repo.scan();
});

final claudeExecutableProvider = FutureProvider<String?>((ref) async {
  final settings = await ref.watch(settingsServiceProvider.future);
  final fromSettings = settings.claudeExecutable;
  if (fromSettings != null && fromSettings.isNotEmpty) return fromSettings;
  final detector = ref.watch(claudeDetectorProvider);
  return detector.detect();
});

/// 主题模式：build() 立即返回 system 不阻塞首帧；[init] 异步读取持久化值覆盖；
/// [set] 同时落盘到 SharedPreferences。
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
