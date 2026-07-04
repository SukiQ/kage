import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/project.dart';
import '../../shared/theme/kage_icons.dart';
import '../../shared/widgets/section_panel.dart';
import '../chat/chat_controller.dart';

class SessionsPanel extends ConsumerStatefulWidget {
  const SessionsPanel({super.key, required this.project});

  final KageProject project;

  @override
  ConsumerState<SessionsPanel> createState() => _SessionsPanelState();
}

class _SessionsPanelState extends ConsumerState<SessionsPanel> {
  Future<List<ChatSessionMeta>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(SessionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) _refresh();
  }

  void _refresh() {
    _future = () async {
      final repo = await ref.read(sessionRepositoryProvider.future);
      return repo.forProject(widget.project.id);
    }();
    setState(() {});
  }

  Future<void> _newSession() async {
    await ref.read(chatControllerProvider.notifier).startNewSession();
    _refresh();
  }

  Future<void> _open(ChatSessionMeta meta) async {
    await ref
        .read(chatControllerProvider.notifier)
        .loadSession(meta, widget.project);
  }

  Future<void> _delete(ChatSessionMeta meta) async {
    final repo = await ref.read(sessionRepositoryProvider.future);
    await repo.delete(meta.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: '历史会话',
      leading: const Icon(KageIcons.history, size: 14),
      trailing: IconButton(
        visualDensity: VisualDensity.compact,
        icon: const Icon(KageIcons.add, size: 16),
        tooltip: '新建会话',
        onPressed: _newSession,
      ),
      child: FutureBuilder<List<ChatSessionMeta>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Text('加载…'),
            );
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(8),
              child: Text('暂无会话'),
            );
          }
          final currentId = ref
              .watch(chatControllerProvider)
              .currentSessionMetaId;
          return Column(
            children: list
                .map(
                  (m) => ListTile(
                    dense: true,
                    selected: m.id == currentId,
                    title: Text(
                      m.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _fmt(m.updatedAt),
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () => _open(m),
                    trailing: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(KageIcons.delete, size: 16),
                      onPressed: () => _delete(m),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  String _fmt(DateTime t) {
    final now = DateTime.now();
    final delta = now.difference(t);
    if (delta.inMinutes < 1) return '刚刚';
    if (delta.inHours < 1) return '${delta.inMinutes} 分钟前';
    if (delta.inDays < 1) return '${delta.inHours} 小时前';
    if (delta.inDays < 7) return '${delta.inDays} 天前';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
