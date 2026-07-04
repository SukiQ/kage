import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/storage/settings_service.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/widgets/kage_title_bar.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _execController = TextEditingController();
  final _apiController = TextEditingController();
  final _sonarHostController = TextEditingController();
  final _sonarTokenController = TextEditingController();
  bool _inited = false;

  @override
  void dispose() {
    _execController.dispose();
    _apiController.dispose();
    _sonarHostController.dispose();
    _sonarTokenController.dispose();
    super.dispose();
  }

  Future<void> _ensureInit() async {
    if (_inited) return;
    _inited = true;
    final settings = await ref.read(settingsServiceProvider.future);
    _execController.text = settings.claudeExecutable ?? '';
    _sonarHostController.text = settings.sonarHost ?? '';
    if (settings.sonarToken != null && settings.sonarToken!.isNotEmpty) {
      _sonarTokenController.text = '********';
    }
    final detector = ref.read(claudeDetectorProvider);
    final f = await detector.settingsFile();
    if (f != null) {
      try {
        final raw = await f.readAsString();
        // 简单解析提取 ANTHROPIC_API_KEY 占位
        if (raw.contains('ANTHROPIC_API_KEY')) {
          _apiController.text = '********';
        }
      } catch (_) {}
    }
    setState(() {});
  }

  Future<void> _saveExec() async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setClaudeExecutable(
      _execController.text.trim().isEmpty ? null : _execController.text.trim(),
    );
  }

  Future<void> _saveApiKey() async {
    final value = _apiController.text.trim();
    if (value.isEmpty || value == '********') return;
    await writeClaudeApiKey(value);
    setState(() => _apiController.text = '********');
  }

  Future<void> _saveSonar() async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setSonarHost(
      _sonarHostController.text.trim().isEmpty
          ? null
          : _sonarHostController.text.trim(),
    );
    final token = _sonarTokenController.text.trim();
    if (token.isNotEmpty && token != '********') {
      await settings.setSonarToken(token);
      setState(() => _sonarTokenController.text = '********');
    }
  }

  Future<void> _resetOnboarding() async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setOnboarded(false);
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInit());
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: KageTitleBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(KageIcons.back),
          tooltip: '返回',
          onPressed: () => context.go('/'),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(KageIcons.contrast),
            title: const Text('主题模式'),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('系统')),
                ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
              ],
              selected: {themeMode},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          const Divider(),
          TextField(
            controller: _execController,
            decoration: const InputDecoration(
              labelText: 'claude 可执行文件路径',
              helperText: '留空将自动从 PATH 与 ~/.claude/local/ 检测',
              border: OutlineInputBorder(),
            ),
            onEditingComplete: _saveExec,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiController,
            decoration: const InputDecoration(
              labelText: 'Anthropic API Key',
              helperText: '写入 ~/.claude/settings.json',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _saveApiKey, child: const Text('保存 API Key')),
          const SizedBox(height: 24),
          const Divider(),
          Text('SonarQube', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _sonarHostController,
            decoration: const InputDecoration(
              labelText: 'SonarQube 地址',
              helperText: '如 https://sonar.example.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sonarTokenController,
            decoration: const InputDecoration(
              labelText: 'SonarQube Token',
              helperText: '用于拉取扫描报告（代码审查结合 SonarQube 时使用）',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saveSonar,
            child: const Text('保存 SonarQube'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            leading: const Icon(KageIcons.restart),
            title: const Text('重新运行首启向导'),
            onTap: _resetOnboarding,
          ),
        ],
      ),
    );
  }
}
