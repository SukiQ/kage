import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/template_renderer.dart';
import '../../data/models/project.dart';
import '../../data/models/prompt_template.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/widgets/kage_title_bar.dart';
import '../../shared/widgets/section_panel.dart';
import '../chat/chat_controller.dart';

class TemplatesPanel extends ConsumerWidget {
  const TemplatesPanel({super.key, required this.project});

  final KageProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(templatesProvider);
    return asyncTemplates.when(
      loading: () => const ListTile(title: Text('加载模板…')),
      error: (e, _) => ListTile(title: Text('模板加载失败: $e')),
      data: (all) => _TemplatesGroup(templates: all, project: project),
    );
  }
}

class _TemplatesGroup extends StatelessWidget {
  const _TemplatesGroup({required this.templates, required this.project});

  final List<PromptTemplate> templates;
  final KageProject project;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: '模板',
      child: templates.isEmpty
          ? const Padding(padding: EdgeInsets.all(8), child: Text('暂无内置模板'))
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: templates
                  .map(
                    (t) => ActionChip(
                      label: Text(t.name),
                      tooltip: t.description,
                      onPressed: () => _open(context, t),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  void _open(BuildContext context, PromptTemplate t) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TemplateRunnerPage(template: t, project: project),
      ),
    );
  }
}

class _TemplateRunnerPage extends ConsumerStatefulWidget {
  const _TemplateRunnerPage({required this.template, required this.project});

  final PromptTemplate template;
  final KageProject project;

  @override
  ConsumerState<_TemplateRunnerPage> createState() => _RunnerState();
}

class _RunnerState extends ConsumerState<_TemplateRunnerPage> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final p in widget.template.parameters)
        p.name: TextEditingController(text: p.defaultValue),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final params = _controllers.map((k, v) => MapEntry(k, v.text));
    final prompt = renderTemplate(widget.template.body, params);
    if (!mounted) return;
    Navigator.of(context).pop();
    await ref
        .read(chatControllerProvider.notifier)
        .send(prompt, widget.project);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return Scaffold(
      appBar: KageTitleBar(title: Text(t.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ...t.parameters.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controllers[p.name],
                  decoration: InputDecoration(
                    labelText: p.label,
                    hintText: p.hint,
                  ),
                  minLines: 1,
                  maxLines: p.multiline ? 6 : 1,
                ),
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _send,
              icon: const Icon(KageIcons.play),
              label: const Text('生成并发送'),
            ),
          ],
        ),
      ),
    );
  }
}
