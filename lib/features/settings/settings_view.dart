import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/sonar/sonar_error.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/widgets/kage_title_bar.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  final _execCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _inited = false;
  bool _tokenDirty = false; // token 是否被修改过（否则是 '****' 占位）
  bool _savingExec = false;
  bool _savingSonar = false;
  _ConnStatus _connStatus = _ConnStatus.idle;
  String? _connError;

  @override
  void dispose() {
    _execCtrl.dispose();
    _hostCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureInit() async {
    if (_inited) return;
    _inited = true;
    final s = await ref.read(settingsServiceProvider.future);
    _execCtrl.text = s.claudeExecutable ?? '';
    _hostCtrl.text = s.sonarHost ?? '';
    if (s.sonarToken?.isNotEmpty ?? false) {
      _tokenCtrl.text = '••••••••';
      _tokenDirty = false;
    }
    if (mounted) setState(() {});
  }

  // ── 保存 Claude 路径 ──────────────────────────────────────────────────────

  Future<void> _saveExec() async {
    setState(() => _savingExec = true);
    try {
      final s = await ref.read(settingsServiceProvider.future);
      await s.setClaudeExecutable(
        _execCtrl.text.trim().isEmpty ? null : _execCtrl.text.trim(),
      );
      ref.invalidate(claudeExecutableProvider);
    } finally {
      if (mounted) setState(() => _savingExec = false);
    }
  }

  // ── AI 模型切换 ───────────────────────────────────────────────────────────

  Widget _modelSelector(ColorScheme cs) {
    final current = ref.watch(activeModelProvider);
    final label = _kModels
        .firstWhere((m) => m.$1 == current, orElse: () => const ('default', '默认'))
        .$2;
    return PopupMenuButton<String>(
      tooltip: '切换模型',
      onSelected: (m) async {
        ref.read(activeModelProvider.notifier).state = m;
        final s = await ref.read(settingsServiceProvider.future);
        await s.setClaudeModel(m);
      },
      itemBuilder: (_) => [
        for (final m in _kModels)
          PopupMenuItem(
            value: m.$1,
            child: Row(children: [
              if (current == m.$1)
                Icon(Icons.check, size: 16, color: cs.primary)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Text(m.$2),
            ]),
          ),
      ],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label),
        const SizedBox(width: 2),
        Icon(Icons.arrow_drop_down, color: cs.onSurfaceVariant),
      ]),
    );
  }

  // ── 测试 SonarQube 连接 ───────────────────────────────────────────────────

  Future<void> _testConn() async {
    final host = _hostCtrl.text.trim();
    final token = _tokenDirty
        ? _tokenCtrl.text.trim()
        : (await ref.read(settingsServiceProvider.future)).sonarToken ?? '';

    if (host.isEmpty || token.isEmpty) {
      setState(() { _connStatus = _ConnStatus.fail; _connError = '地址或 Token 为空'; });
      return;
    }
    setState(() { _connStatus = _ConnStatus.testing; _connError = null; });
    try {
      final resp = await Dio(BaseOptions(
        baseUrl: host.replaceAll(RegExp(r'/+$'), ''),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
      )).get('/api/system/status',
          options: Options(headers: {
            'Authorization': 'Basic ${_basicAuth(token)}',
          }));
      final ok = resp.data?['status'] == 'UP';
      setState(() => _connStatus = ok ? _ConnStatus.ok : _ConnStatus.fail);
      if (!ok) _connError = '系统状态非 UP：${resp.data?['status']}';
    } catch (e) {
      setState(() { _connStatus = _ConnStatus.fail; _connError = describeSonarError(e); });
    }
  }

  // ── 保存 SonarQube 设置 ───────────────────────────────────────────────────

  Future<void> _saveSonar() async {
    setState(() => _savingSonar = true);
    try {
      final s = await ref.read(settingsServiceProvider.future);
      await s.setSonarHost(
        _hostCtrl.text.trim().isEmpty ? null : _hostCtrl.text.trim(),
      );
      if (_tokenDirty) {
        final t = _tokenCtrl.text.trim();
        await s.setSonarToken(t.isEmpty ? null : t);
        if (mounted) {
          setState(() {
            _tokenCtrl.text = t.isEmpty ? '' : '••••••••';
            _tokenDirty = false;
          });
        }
      }
      // 使扫描器 provider 失效，下次扫描用新配置
      ref.invalidate(activeScannerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SonarQube 设置已保存'), duration: Duration(seconds: 2)),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSonar = false);
    }
  }

  Future<void> _resetOnboarding() async {
    final s = await ref.read(settingsServiceProvider.future);
    await s.setOnboarded(false);
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureInit());
    final themeMode = ref.watch(themeModeProvider);
    final cs = Theme.of(context).colorScheme;

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── 外观 ───────────────────────────────────────────────────────────
          _sectionTitle(context, '外观'),
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
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),

          const SizedBox(height: 24),

          // ── Claude 代码智能 ────────────────────────────────────────────────
          _sectionTitle(context, 'Claude 代码智能'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _execCtrl,
                decoration: const InputDecoration(
                  labelText: 'claude 可执行文件路径',
                  helperText: '留空将自动从 PATH 与 ~/.claude/local/ 检测',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _savingExec ? null : _saveExec,
              child: _savingExec
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('保存'),
            ),
          ],
          ),
          ListTile(
            contentPadding: const EdgeInsets.only(top: 4),
            leading: const Icon(Icons.hub_outlined),
            title: const Text('AI 模型'),
            subtitle: const Text('所有 AI 分析（质量 / 架构 / 性能等）共用的 Claude 模型'),
            trailing: _modelSelector(cs),
          ),

          const SizedBox(height: 28),

          // ── SonarQube ──────────────────────────────────────────────────────
          _sectionTitle(context, 'SonarQube'),
          const SizedBox(height: 8),
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: 'SonarQube 地址',
              hintText: 'https://sonar.example.com',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _connStatus = _ConnStatus.idle),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenCtrl,
            obscureText: !_tokenDirty,
            decoration: InputDecoration(
              labelText: 'SonarQube Token',
              helperText: '全局 Token，供所有项目扫描使用',
              border: const OutlineInputBorder(),
              suffixIcon: _tokenDirty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: '修改 Token',
                      onPressed: () => setState(() {
                        _tokenCtrl.text = '';
                        _tokenDirty = true;
                      }),
                    ),
            ),
            onChanged: (_) {
              if (!_tokenDirty) setState(() => _tokenDirty = true);
              setState(() => _connStatus = _ConnStatus.idle);
            },
          ),
          const SizedBox(height: 12),
          Row(children: [
            // 测试连接
            OutlinedButton.icon(
              onPressed: _connStatus == _ConnStatus.testing ? null : _testConn,
              icon: _connStatus == _ConnStatus.testing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_connIcon(_connStatus), size: 16, color: _connColor(cs, _connStatus)),
              label: const Text('测试连接'),
            ),
            const SizedBox(width: 12),
            if (_connStatus == _ConnStatus.ok)
              Text('连接成功', style: TextStyle(color: cs.primary, fontSize: 13)),
            if (_connStatus == _ConnStatus.fail && _connError != null)
              Flexible(
                child: Text(
                  _connError!,
                  style: TextStyle(color: cs.error, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const Spacer(),
            FilledButton(
              onPressed: _savingSonar ? null : _saveSonar,
              child: _savingSonar
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('保存'),
            ),
          ]),

          const SizedBox(height: 28),
          const Divider(),

          // ── 高级 ───────────────────────────────────────────────────────────
          _sectionTitle(context, '高级'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(KageIcons.restart),
            title: const Text('重新运行首启向导'),
            onTap: _resetOnboarding,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      );

  String _basicAuth(String token) {
    return base64Encode(utf8.encode('$token:'));
  }

  IconData _connIcon(_ConnStatus s) => switch (s) {
        _ConnStatus.ok => Icons.check_circle_outline,
        _ConnStatus.fail => Icons.error_outline,
        _ => Icons.wifi_tethering_rounded,
      };

  Color _connColor(ColorScheme cs, _ConnStatus s) => switch (s) {
        _ConnStatus.ok => cs.primary,
        _ConnStatus.fail => cs.error,
        _ => cs.onSurfaceVariant,
      };
}

enum _ConnStatus { idle, testing, ok, fail }

const _kModels = <(String, String)>[
  ('default', '默认'),
  ('sonnet', 'Sonnet'),
  ('opus', 'Opus'),
  ('haiku', 'Haiku'),
  ('fable', 'Fable'),
];
