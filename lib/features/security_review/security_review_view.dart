import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/analysis_dimension.dart';
import '../../core/analysis/analysis_prompt.dart';
import '../../core/analysis/analysis_session_controller.dart';
import '../../core/scanners/scan_result.dart';
import '../../data/models/issue_record.dart';
import '../../data/models/project.dart';
import '../../shared/widgets/analysis_panel.dart';

class SecurityReviewView extends ConsumerStatefulWidget {
  const SecurityReviewView({super.key, required this.project});
  final KageProject project;

  @override
  ConsumerState<SecurityReviewView> createState() => _SecurityReviewViewState();
}

class _SecurityReviewViewState extends ConsumerState<SecurityReviewView> {
  bool _showAi = false;

  static const _dim = AnalysisDimension.securityReview;

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(activeScanResultProvider);
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _toolbar(context, cs, result),
              Expanded(
                child: result == null ? _empty(context, cs) : _body(context, cs, result),
              ),
            ],
          ),
        ),
        if (_showAi)
          Container(
            width: 400,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: cs.outlineVariant)),
            ),
            child: const AnalysisPanel(dimension: AnalysisDimension.securityReview),
          ),
      ],
    );
  }

  Widget _toolbar(BuildContext context, ColorScheme cs, ScanResult? result) {
    final session = ref.watch(analysisSessionProvider(_dim));
    final running = session.running;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 18),
          const SizedBox(width: 8),
          Text('安全审查', style: Theme.of(context).textTheme.titleSmall),
          if (result != null) ...[
            const SizedBox(width: 12),
            _chip('漏洞', result.metrics.vulnerabilities, const Color(0xFFD94F4F)),
            const SizedBox(width: 6),
            _chip('安全热点', result.metrics.securityHotspots, const Color(0xFFE07A2D)),
            const SizedBox(width: 6),
            if (result.metrics.securityRating != null)
              _ratingChip('安全评级', result.metrics.securityRating!),
          ],
          const Spacer(),
          // 一键修复
          FilledButton.icon(
            onPressed: result == null || running ? null : () => _fixAll(result),
            icon: running
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.build_outlined, size: 16),
            label: Text(running ? '处理中…' : '一键修复'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          const SizedBox(width: 4),
          // 导出安全报告
          IconButton(
            icon: const Icon(Icons.download_outlined, size: 18),
            tooltip: '导出安全报告',
            visualDensity: VisualDensity.compact,
            onPressed: result == null ? null : _exportReport,
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(_showAi ? Icons.close_fullscreen_outlined : Icons.open_in_new_outlined, size: 16),
            tooltip: _showAi ? '收起面板' : '展开面板',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _showAi = !_showAi),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, ColorScheme cs) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_outlined, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('请先在总览页执行扫描'),
        ]),
      );

  Widget _body(BuildContext context, ColorScheme cs, ScanResult result) {
    final stored = ref.watch(issueRecordsProvider);
    final records = _securityRecords(stored, result);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _metricsRow(context, cs, result),
          const SizedBox(height: 20),
          Text('安全问题（${records.length} 条）', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          if (records.isEmpty)
            _safeBanner()
          else
            ...records.take(50).map((r) => _secTile(context, cs, r)),
        ],
      ),
    );
  }

  Widget _safeBanner() => Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF3DAA6E).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3DAA6E).withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_outlined, color: Color(0xFF3DAA6E), size: 20),
            SizedBox(width: 8),
            Text('未发现安全漏洞', style: TextStyle(color: Color(0xFF3DAA6E), fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _metricsRow(BuildContext context, ColorScheme cs, ScanResult result) {
    final m = result.metrics;
    return Wrap(spacing: 10, runSpacing: 10, children: [
      if (m.vulnerabilities != null)
        _card(context, cs, '漏洞', '${m.vulnerabilities}', const Color(0xFFD94F4F), Icons.bug_report_outlined),
      if (m.securityHotspots != null)
        _card(context, cs, '安全热点', '${m.securityHotspots}', const Color(0xFFE07A2D), Icons.local_fire_department_outlined),
      if (m.securityRating != null)
        _card(context, cs, '安全评级', m.securityRating!, const Color(0xFF6B7FD7), Icons.grade_outlined),
    ]);
  }

  Widget _card(BuildContext context, ColorScheme cs, String label, String value, Color color, IconData icon) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  // ── 数据源：扫描结果 → IssueRecord，按安全类型过滤 ────────────────────────────

  List<IssueRecord> _recordsFromScan(ScanResult result) => result.issues
      .where((i) => i.type == ScanIssueType.vulnerability || i.type == ScanIssueType.securityHotspot)
      .map((i) => IssueRecord(
            id: i.key,
            projectId: widget.project.id,
            scannerType: i.scannerType,
            issueKey: i.key,
            severity: i.severity.label,
            type: i.type.name,
            component: i.component,
            line: i.line,
            rule: i.rule,
            message: i.message,
            effort: i.effort,
            status: IssueStatus.open,
            createdAt: result.scannedAt,
            updatedAt: result.scannedAt,
          ))
      .toList();

  bool _isSecurity(IssueRecord r) =>
      r.type == ScanIssueType.vulnerability.name || r.type == ScanIssueType.securityHotspot.name;

  List<IssueRecord> _securityRecords(List<IssueRecord> stored, ScanResult result) {
    final all = stored.isNotEmpty ? stored : _recordsFromScan(result);
    return all.where(_isSecurity).toList();
  }

  // ── 安全问题卡片（含修复 / 忽略 / 重新计入）──────────────────────────────────

  Widget _secTile(BuildContext context, ColorScheme cs, IssueRecord r) {
    final isVuln = r.type == ScanIssueType.vulnerability.name;
    final sevColor = _sevColor(r.severity);
    final running = ref.watch(analysisSessionProvider(_dim)).running;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Icon(
            isVuln ? Icons.security_outlined : Icons.local_fire_department_outlined,
            size: 16,
            color: sevColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                '${r.component}:${r.line ?? '-'}  ·  ${r.rule}  ·  ${r.severity}',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (r.status == IssueStatus.open)
            Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                onPressed: running ? null : () => _showFixDialog(r),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF3DAA6E),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('修复', style: TextStyle(fontSize: 12)),
              ),
              TextButton(
                onPressed: running ? null : () => _ignore(r),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('忽略', style: TextStyle(fontSize: 12)),
              ),
            ])
          else if (r.status == IssueStatus.ignored)
            Row(mainAxisSize: MainAxisSize.min, children: [
              _StatusChip(status: r.status),
              const SizedBox(width: 4),
              TextButton(
                onPressed: running ? null : () => _restore(r),
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重新计入', style: TextStyle(fontSize: 12)),
              ),
            ])
          else
            _StatusChip(status: r.status),
        ]),
      ),
    );
  }

  // ── 操作：修复 / 忽略 / 一键修复 ────────────────────────────────────────────

  Future<void> _refreshIssues() async {
    final repo = await ref.read(issueRepositoryProvider.future);
    final records = await repo.forProject(widget.project.id);
    if (mounted) ref.read(issueRecordsProvider.notifier).state = records;
  }

  Future<void> _ignore(IssueRecord r) async {
    final repo = await ref.read(issueRepositoryProvider.future);
    await repo.updateStatus(widget.project.id, r.issueKey, IssueStatus.ignored);
    await _refreshIssues();
  }

  /// 重新计入：把已忽略的安全问题恢复为待处理。
  Future<void> _restore(IssueRecord r) async {
    final repo = await ref.read(issueRepositoryProvider.future);
    await repo.updateStatus(widget.project.id, r.issueKey, IssueStatus.open);
    await _refreshIssues();
  }

  /// 单个修复：弹窗填写附言（按 rule 预填/记忆）→ 调 AI 安全修复 → 标记已修复。
  Future<void> _showFixDialog(IssueRecord r) async {
    final noteRepo = await ref.read(ruleNoteRepositoryProvider.future);
    if (!mounted) return;
    final controller = TextEditingController(text: noteRepo.getNote(r.rule) ?? '');
    final cs = Theme.of(context).colorScheme;

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 修复安全问题'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.message, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${r.component}:${r.line ?? '-'}  ·  ${r.rule}',
                style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '修复附言（可选）',
                  helperText: '对该类漏洞的修复方式/偏好，相同错误码将自动复用',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
            label: const Text('开始修复'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note == null || !mounted) return; // 用户取消

    // 持久化附言（按 rule 全局记忆）
    await noteRepo.setNote(r.rule, note);

    setState(() => _showAi = true);
    await ref.read(analysisSessionProvider(_dim).notifier).startFix(
          project: widget.project,
          dimension: _dim,
          prompt: AnalysisPrompt.buildFixSingleMessage(r, note, dimension: _dim),
          onComplete: () async {
            final repo = await ref.read(issueRepositoryProvider.future);
            await repo.updateStatus(
              widget.project.id,
              r.issueKey,
              IssueStatus.fixed,
              comment: note.isEmpty ? null : note,
            );
            await _refreshIssues();
          },
        );
  }

  /// 一键修复：调 AI 批量修复所有待处理（open）的安全问题。
  Future<void> _fixAll(ScanResult result) async {
    final stored = ref.read(issueRecordsProvider);
    final records = _securityRecords(stored, result);
    final openIssues = records.where((r) => r.status == IssueStatus.open).toList();
    if (openIssues.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有待处理的安全问题'), duration: Duration(seconds: 2)),
      );
      return;
    }
    final noteRepo = await ref.read(ruleNoteRepositoryProvider.future);
    if (!mounted) return;
    final issueKeys = openIssues.map((e) => e.issueKey).toList();

    setState(() => _showAi = true);
    await ref.read(analysisSessionProvider(_dim).notifier).startFix(
          project: widget.project,
          dimension: _dim,
          prompt: AnalysisPrompt.buildFixAllMessage(openIssues, noteRepo.all, dimension: _dim),
          onComplete: () async {
            final repo = await ref.read(issueRepositoryProvider.future);
            await repo.markFixed(widget.project.id, issueKeys);
            await _refreshIssues();
          },
        );
  }

  // ── 导出安全审查报告（Markdown）──────────────────────────────────────────────

  Future<void> _exportReport() async {
    final result = ref.read(activeScanResultProvider);
    if (result == null) return;
    final stored = ref.read(issueRecordsProvider);
    final records = _securityRecords(stored, result);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出安全审查报告',
      fileName: '安全审查报告-${widget.project.name}.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
      lockParentWindow: true,
    );
    if (path == null) return; // 用户取消
    try {
      await File(path).writeAsString(_buildReport(result, records));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导出报告：$path'), duration: const Duration(seconds: 3)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导出失败：$e')));
      }
    }
  }

  String _buildReport(ScanResult result, List<IssueRecord> records) {
    final m = result.metrics;
    final vulns = m.vulnerabilities;
    final hot = m.securityHotspots;
    final rating = m.securityRating;
    final gate = result.qualityGateStatus;
    final buf = StringBuffer()
      ..writeln('# 安全审查报告 · ${widget.project.name}')
      ..writeln()
      ..writeln('> 生成时间：${_stamp(DateTime.now())}')
      ..writeln('> 扫描器：${result.scannerType}')
      ..writeln()
      ..writeln('## 安全概览')
      ..writeln('- 漏洞：${vulns ?? '—'}')
      ..writeln('- 安全热点：${hot ?? '—'}')
      ..writeln('- 安全评级：${rating ?? '—'}')
      ..writeln('- 质量门禁：${gate ?? '未知'}')
      ..writeln();

    final sevCounts = <String, int>{};
    for (final r in records) {
      sevCounts[r.severity] = (sevCounts[r.severity] ?? 0) + 1;
    }
    if (sevCounts.isNotEmpty) {
      buf.writeln('## 严重度分布');
      for (final s in const ['BLOCKER', 'CRITICAL', 'MAJOR', 'MINOR', 'INFO']) {
        if (sevCounts.containsKey(s)) buf.writeln('- $s：${sevCounts[s]}');
      }
      buf.writeln();
    }

    buf.writeln('## 安全问题清单（${records.length} 条）');
    if (records.isEmpty) {
      buf.writeln('（未发现安全问题）');
    } else {
      for (var i = 0; i < records.length; i++) {
        final r = records[i];
        buf
          ..writeln()
          ..writeln('### ${i + 1}. [${r.severity}] ${_typeLabel(r.type)} — ${_cell(r.message)}')
          ..writeln()
          ..writeln('- 文件：${_cell(r.component)}:${r.line ?? '-'}')
          ..writeln('- 规则：${_cell(r.rule)}')
          ..writeln('- 状态：${r.status.label}');
        if (r.comment != null && r.comment!.isNotEmpty) {
          buf.writeln('- 附言：${_cell(r.comment!)}');
        }
      }
    }
    return buf.toString();
  }

  String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  String _cell(String s) => s.replaceAll('|', '\\|').replaceAll('\n', ' ');

  // type 取自 ScanIssueType.name（enum.name 非编译期常量，故用字面量匹配）
  String _typeLabel(String t) => switch (t) {
        'vulnerability' => '漏洞',
        'securityHotspot' => '安全热点',
        _ => t,
      };

  Color _sevColor(String s) => switch (s) {
        'BLOCKER' => const Color(0xFFD94F4F),
        'CRITICAL' => const Color(0xFFD94F4F),
        'MAJOR' => const Color(0xFFE07A2D),
        'MINOR' => const Color(0xFFE0A152),
        _ => const Color(0xFF9AA0A8),
      };

  Widget _chip(String label, int? value, Color color) {
    if (value == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _ratingChip(String label, String rating) {
    final color = switch (rating) {
      'A' => const Color(0xFF3DAA6E),
      'B' => const Color(0xFF6B7FD7),
      'C' => const Color(0xFFE0A152),
      _ => const Color(0xFFD94F4F),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label: $rating', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final IssueStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (fg, bg) = switch (status) {
      IssueStatus.open => (cs.error, cs.error.withValues(alpha: 0.12)),
      IssueStatus.inProgress => (const Color(0xFF6B7FD7), const Color(0xFF6B7FD7).withValues(alpha: 0.12)),
      IssueStatus.fixed => (const Color(0xFF3DAA6E), const Color(0xFF3DAA6E).withValues(alpha: 0.12)),
      _ => (cs.onSurfaceVariant, cs.onSurfaceVariant.withValues(alpha: 0.1)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
