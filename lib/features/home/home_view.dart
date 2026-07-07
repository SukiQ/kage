import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/models/project.dart';
import '../../core/analysis/analysis_dimension.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/widgets/kage_title_bar.dart';
import '../arch_analysis/arch_analysis_view.dart';
import '../code_quality/code_quality_view.dart';
import '../overview/overview_view.dart';
import '../perf_analysis/perf_analysis_view.dart';
import '../projects/projects_dialog.dart';
import '../quality_test/quality_test_view.dart';
import '../security_review/security_review_view.dart';

enum _NavItem { overview, codeQuality, security, architecture, performance, testing }

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  _NavItem _selected = _NavItem.overview;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!settings.onboarded) {
      if (mounted) context.go('/onboarding');
      return;
    }
    final pid = settings.activeProjectId;
    if (pid != null) {
      final repo = await ref.read(projectRepositoryProvider.future);
      final p = repo.findById(pid);
      if (p != null) await _applyProject(p);
    }
  }

  /// 应用（切换/恢复）当前项目：同步激活态、持久化，并重置扫描结果、加载该项目 issue 记录。
  Future<void> _applyProject(KageProject p) async {
    ref.read(activeProjectProvider.notifier).state = p;
    final s = await ref.read(settingsServiceProvider.future);
    await s.setActiveProjectId(p.id);
    // 切换项目后重置扫描结果，避免显示上一个项目的数据
    ref.read(activeScanResultProvider.notifier).state = null;
    // 加载该项目的 issue 生命周期记录
    final issueRepo = await ref.read(issueRepositoryProvider.future);
    final records = await issueRepo.forProject(p.id);
    ref.read(issueRecordsProvider.notifier).state = records;
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(activeProjectProvider);
    return Scaffold(
      appBar: KageTitleBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: SvgPicture.asset(
            'assets/images/logo.svg',
            width: 20,
            height: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(KageIcons.settings),
            tooltip: '设置',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: project == null ? _emptyState(context) : _mainLayout(project.name),
    );
  }

  Widget _mainLayout(String projectName) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // 左侧导航栏
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(right: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(
            children: [
              // 项目选择器
              _projectSelector(context, cs, projectName),
              const Divider(height: 1),
              // 导航项
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  children: [
                    _navTile(
                      context,
                      _NavItem.overview,
                      Icons.dashboard_outlined,
                      '总览',
                    ),
                    const SizedBox(height: 4),
                    _navTile(
                      context,
                      _NavItem.codeQuality,
                      Icons.code_outlined,
                      '代码质量',
                    ),
                    _navTile(
                      context,
                      _NavItem.security,
                      Icons.shield_outlined,
                      '安全审查',
                    ),
                    _navTile(
                      context,
                      _NavItem.architecture,
                      Icons.layers_outlined,
                      '架构分析',
                    ),
                    _navTile(
                      context,
                      _NavItem.performance,
                      Icons.speed_outlined,
                      '性能分析',
                    ),
                    _navTile(
                      context,
                      _NavItem.testing,
                      Icons.science_outlined,
                      '质量测试',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 右侧内容区
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    final project = ref.watch(activeProjectProvider);
    if (project == null) return const SizedBox.shrink();
    // 用 IndexedStack 常驻所有子页面，保留各页面本地扫描/分析状态，
    // 切换侧边栏不再丢失结果、无需重新扫描。
    return IndexedStack(
      index: _selected.index,
      children: [
        OverviewView(project: project),
        CodeQualityView(project: project),
        SecurityReviewView(project: project),
        ArchAnalysisView(project: project),
        PerfAnalysisView(project: project),
        QualityTestView(project: project),
      ],
    );
  }

  Widget _projectSelector(BuildContext context, ColorScheme cs, String name) {
    final projects = ref.watch(projectRepositoryProvider).valueOrNull?.all ?? [];
    // 去掉点击水波纹反馈动画与悬停 tooltip，保持下拉框交互干净。
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Icon(KageIcons.folder, size: 18, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(KageIcons.dropdown, size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
        itemBuilder: (_) => [
          ...projects.map((p) => PopupMenuItem(value: p.id, child: Text(p.name))),
          const PopupMenuDivider(),
          const PopupMenuItem(value: '__manage__', child: Text('管理项目…')),
        ],
        onSelected: (value) async {
          if (value == '__manage__') {
            showDialog(context: context, builder: (_) => const ProjectsDialog());
            return;
          }
          final p = projects.firstWhere((e) => e.id == value);
          await _applyProject(p);
        },
      ),
    );
  }

  Widget _navTile(BuildContext context, _NavItem item, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    final selected = _selected == item;
    return InkWell(
      onTap: () => setState(() {
        _selected = item;
        // 同步到 provider（用于 AI 分析维度）
        final dim = switch (item) {
          _NavItem.codeQuality => AnalysisDimension.codeQuality,
          _NavItem.security => AnalysisDimension.securityReview,
          _NavItem.architecture => AnalysisDimension.archAnalysis,
          _NavItem.performance => AnalysisDimension.perfAnalysis,
          _NavItem.testing => AnalysisDimension.qualityTest,
          _ => AnalysisDimension.codeQuality,
        };
        if (item != _NavItem.overview) {
          ref.read(activeDimensionProvider.notifier).state = dim;
        }
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? cs.onSecondaryContainer : cs.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(KageIcons.folderOff,
                size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('还没有可用的项目'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const ProjectsDialog(),
              ),
              child: const Text('添加项目'),
            ),
          ],
        ),
      );
}
