import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../data/models/project.dart';
import '../../shared/theme/kage_icons.dart';

class ProjectsDialog extends ConsumerStatefulWidget {
  const ProjectsDialog({super.key});

  @override
  ConsumerState<ProjectsDialog> createState() => _ProjectsDialogState();
}

class _ProjectsDialogState extends ConsumerState<ProjectsDialog> {
  String? _selectedPath;
  String? _extractedName;

  Future<void> _pick() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _selectedPath = result;
        _extractedName = p.basename(result);
      });
    }
  }

  Future<void> _save() async {
    if (_selectedPath == null || _extractedName == null) return;
    final repo = await ref.read(projectRepositoryProvider.future);
    final project = await repo.add(
      name: _extractedName!,
      path: _selectedPath!,
    );
    // 自动设为当前项目
    ref.read(activeProjectProvider.notifier).state = project;
    final s = await ref.read(settingsServiceProvider.future);
    await s.setActiveProjectId(project.id);
    setState(() {
      _selectedPath = null;
      _extractedName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncProjects = ref.watch(projectRepositoryProvider);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('项目管理'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 添加新项目 ──────────────────────────────────────────────────
            Text('添加项目', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            // 选择目录按钮 + 显示选中路径和提取的项目名
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(KageIcons.folderOpen, size: 18),
              label: Text(_selectedPath == null ? '选择项目目录' : '更换目录'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
              ),
            ),
            if (_selectedPath != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.badge_outlined, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text('项目名称：', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      Text(_extractedName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.folder_outlined, size: 16, color: cs.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _selectedPath!,
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // ── 已有项目列表 ────────────────────────────────────────────────
            Text('已添加项目', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Flexible(
              child: asyncProjects.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载失败: $e'),
                data: (repo) {
                  final list = repo.all;
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('暂无项目', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ProjectRow(
                      project: list[i],
                      repo: repo,
                      onActivate: () {
                        ref.read(activeProjectProvider.notifier).state = list[i];
                        ref.read(settingsServiceProvider.future)
                            .then((s) => s.setActiveProjectId(list[i].id));
                        Navigator.of(context).pop();
                      },
                      onChanged: () => setState(() {}),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
        FilledButton(
          onPressed: _selectedPath == null ? null : _save,
          child: const Text('添加项目'),
        ),
      ],
    );
  }
}

/// 项目行：显示名称、路径，支持设为当前与删除。
/// 项目名称即作为 SonarQube project key，无需单独维护。
class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.repo,
    required this.onActivate,
    required this.onChanged,
  });

  final KageProject project;
  final dynamic repo; // ProjectRepository
  final VoidCallback onActivate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                project.path,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(KageIcons.check, size: 18),
          tooltip: '设为当前',
          onPressed: onActivate,
        ),
        IconButton(
          icon: const Icon(KageIcons.delete, size: 18),
          tooltip: '删除',
          onPressed: () async {
            await repo.delete(project.id);
            onChanged();
          },
        ),
      ]),
    );
  }
}
