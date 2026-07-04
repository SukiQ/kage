import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/project.dart';
import '../../data/models/skill.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/widgets/section_panel.dart';
import '../chat/chat_controller.dart';

class SkillsPanel extends ConsumerWidget {
  const SkillsPanel({super.key, required this.project});

  final KageProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSkills = ref.watch(skillsProvider);
    return SectionPanel(
      title: 'Skills',
      leading: const Icon(KageIcons.skills, size: 14),
      child: asyncSkills.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(8),
          child: Text('扫描 Skills…'),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(8),
          child: Text('读取 Skills 失败: $e'),
        ),
        data: (skills) {
          if (skills.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Text('没有可用的 Skill'),
            );
          }
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            children: skills
                .map(
                  (s) => ActionChip(
                    label: Text(s.name),
                    tooltip: s.description,
                    onPressed: () => _confirm(context, ref, s),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    KageSkill skill,
  ) async {
    final extra = await showDialog<String>(
      context: context,
      builder: (_) => const _SkillArgDialog(),
    );
    if (extra == null) return;
    final payload = '/${skill.name}${extra.isEmpty ? "" : " $extra"}';
    await ref.read(chatControllerProvider.notifier).send(payload, project);
  }
}

class _SkillArgDialog extends StatefulWidget {
  const _SkillArgDialog();

  @override
  State<_SkillArgDialog> createState() => _SkillArgDialogState();
}

class _SkillArgDialogState extends State<_SkillArgDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Skill 输入'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(labelText: '附加参数（可空）'),
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('运行'),
        ),
      ],
    );
  }
}
