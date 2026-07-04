import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/widgets/kage_title_bar.dart';
import '../chat/chat_view.dart';
import '../projects/projects_dialog.dart';
import 'sidebar_menu.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  bool _sidebarOpen = true;

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
      if (p != null) {
        ref.read(activeProjectProvider.notifier).state = p;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(activeProjectProvider);
    return Scaffold(
      appBar: KageTitleBar(
        leading: IconButton(
          icon: Icon(
            _sidebarOpen ? KageIcons.sidebarClose : KageIcons.sidebarOpen,
          ),
          tooltip: _sidebarOpen ? '收起侧栏' : '展开侧栏',
          onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
        ),
        actions: [
          IconButton(
            icon: const Icon(KageIcons.settings),
            tooltip: '设置',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: project == null
          ? _emptyState(context)
          : Row(
              children: [
                if (_sidebarOpen) SidebarMenu(project: project),
                Expanded(child: ChatView(project: project)),
              ],
            ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            KageIcons.folderOff,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
}
