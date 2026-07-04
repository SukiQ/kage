import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/theme/kage_icons.dart';

class ProjectsDialog extends ConsumerStatefulWidget {
  const ProjectsDialog({super.key});

  @override
  ConsumerState<ProjectsDialog> createState() => _ProjectsDialogState();
}

class _ProjectsDialogState extends ConsumerState<ProjectsDialog> {
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  final _sonarKeyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _sonarKeyController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _ManualPathDialog(initial: _pathController.text),
    );
    if (picked != null) _pathController.text = picked;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final path = _pathController.text.trim();
    if (name.isEmpty || path.isEmpty) return;
    final repo = await ref.read(projectRepositoryProvider.future);
    final sonarKey = _sonarKeyController.text.trim();
    await repo.add(
      name: name,
      path: path,
      sonarProjectKey: sonarKey.isEmpty ? null : sonarKey,
    );
    _nameController.clear();
    _pathController.clear();
    _sonarKeyController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final asyncProjects = ref.watch(projectRepositoryProvider);
    return AlertDialog(
      title: const Text('项目（工作目录）'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '名称'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(labelText: '工作目录'),
                  ),
                ),
                IconButton(
                  onPressed: _pick,
                  icon: const Icon(KageIcons.folderOpen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sonarKeyController,
              decoration: const InputDecoration(
                labelText: 'SonarQube Project Key（可空）',
                helperText: '用于代码审查时拉取扫描报告',
              ),
            ),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '已添加项目',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Flexible(
              child: asyncProjects.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载失败: $e'),
                data: (repo) => ListView(
                  shrinkWrap: true,
                  children: repo.all
                      .map(
                        (p) => ListTile(
                          title: Text(p.name),
                          subtitle: Text(p.path),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(KageIcons.check),
                                tooltip: '设为当前',
                                onPressed: () {
                                  ref
                                          .read(activeProjectProvider.notifier)
                                          .state =
                                      p;
                                  ref
                                      .read(settingsServiceProvider.future)
                                      .then((s) => s.setActiveProjectId(p.id));
                                  Navigator.of(context).pop();
                                },
                              ),
                              IconButton(
                                icon: const Icon(KageIcons.delete),
                                tooltip: '删除',
                                onPressed: () async {
                                  await repo.delete(p.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
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
        FilledButton(onPressed: _save, child: const Text('添加')),
      ],
    );
  }
}

/// 简化版：手工输入路径。后续可接入 file_picker 替换。
class _ManualPathDialog extends StatelessWidget {
  const _ManualPathDialog({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initial);
    return AlertDialog(
      title: const Text('输入工作目录绝对路径'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(
          hintText: '/absolute/path/to/project',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
