import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/storage/settings_service.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/theme/kage_tokens.dart';
import '../../shared/widgets/kage_brand.dart';
import '../../shared/widgets/kage_title_bar.dart';

class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _apiKeyController = TextEditingController();
  String? _claudePath;
  String? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _detect() async {
    final detector = ref.read(claudeDetectorProvider);
    final exec = await detector.detect();
    final settings = await ref.read(settingsServiceProvider.future);
    setState(() {
      _claudePath = exec;
      if (settings.claudeExecutable == null && exec != null) {
        settings.setClaudeExecutable(exec);
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() => _status = 'API Key 不能为空');
      return;
    }
    try {
      await writeClaudeApiKey(key);
      final settings = await ref.read(settingsServiceProvider.future);
      await settings.setOnboarded(true);
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _status = '保存失败：$e');
    }
  }

  Future<void> _skip() async {
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setOnboarded(true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KageTitleBar(title: KageBrand()),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: KageBrand(iconSize: 40, fontSize: 22),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '欢迎使用 Kage',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    _claudeStatus(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Anthropic API Key',
                        hintText: 'sk-ant-...',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '该 Key 会写入 ~/.claude/settings.json，由本机 claude CLI 读取使用。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (_status != null)
                      Text(
                        _status!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(onPressed: _save, child: const Text('保存并开始')),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _skip,
                      child: const Text('我已有配置，跳过'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _claudeStatus() {
    final cs = Theme.of(context).colorScheme;
    final tok = KageDesignTokens.of(context);
    if (_claudePath == null) {
      return _statusBlock(
        icon: KageIcons.alert,
        iconColor: cs.error,
        title: '未检测到 claude CLI',
        body: '请先在 https://claude.com/claude-code 安装，再启动 Kage。',
        tok: tok,
      );
    }
    return _statusBlock(
      icon: KageIcons.check,
      iconColor: cs.primary,
      title: '检测到 claude CLI',
      body: _claudePath!,
      tok: tok,
    );
  }

  Widget _statusBlock({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required KageDesignTokens tok,
  }) {
    final t = Theme.of(context);
    final cs = t.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(tok.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
