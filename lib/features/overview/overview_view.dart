import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/analysis/analysis_dimension.dart';
import '../../core/scanners/scan_result.dart';
import '../../data/models/project.dart';
import '../../shared/theme/kage_icons.dart';

/// 总览仪表板：5个维度的评分卡片 + SonarQube 质量门禁状态
class OverviewView extends ConsumerStatefulWidget {
  const OverviewView({super.key, required this.project});
  final KageProject project;

  @override
  ConsumerState<OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends ConsumerState<OverviewView> {
  bool _scanning = false;
  String? _error;
  String? _progress;

  Future<void> _runScan() async {
    setState(() { _scanning = true; _error = null; _progress = null; });
    try {
      final scanner = await ref.read(activeScannerProvider.future);
      final err = scanner.validate(widget.project);
      if (err != null) {
        setState(() { _error = err; _scanning = false; });
        return;
      }
      final result = await scanner.scan(
        widget.project,
        onProgress: (msg) { if (mounted) setState(() => _progress = msg); },
      );
      ref.read(activeScanResultProvider.notifier).state = result;
      final repo = await ref.read(issueRepositoryProvider.future);
      final records = await repo.syncFromScan(widget.project.id, result.issues);
      ref.read(issueRecordsProvider.notifier).state = records;
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() { _scanning = false; _progress = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(activeScanResultProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: result == null ? _empty(context) : _dashboard(context, result),
    );
  }

  Widget _empty(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(KageIcons.codeReview, size: 56, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('尚未执行扫描', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.error, fontSize: 13, height: 1.5),
                ),
              ),
            ],
            if (_progress != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.primary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _progress!,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            FilledButton.icon(
              onPressed: _scanning ? null : _runScan,
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.radar_rounded, size: 18),
              label: Text(_scanning ? '扫描中…' : '立即扫描'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboard(BuildContext context, ScanResult result) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 质量门禁状态
          _gateStatus(context, cs, result),
          const SizedBox(height: 20),
          // 5维度评分卡片网格
          Text('质量治理维度', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          _dimensionGrid(context, cs, result),
        ],
      ),
    );
  }

  Widget _gateStatus(BuildContext context, ColorScheme cs, ScanResult result) {
    final passed = result.qualityGateStatus == 'OK';
    final gateColor = result.qualityGateStatus == null
        ? cs.onSurfaceVariant
        : passed
            ? const Color(0xFF3DAA6E)
            : cs.error;
    final gateLabel = switch (result.qualityGateStatus) {
      'OK' => '质量门禁：通过',
      'ERROR' => '质量门禁：未通过',
      _ => '质量门禁：未知',
    };
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: gateColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: gateColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                  passed
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                  size: 16,
                  color: gateColor),
              const SizedBox(width: 6),
              Text(gateLabel,
                  style: TextStyle(
                      color: gateColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${result.scannerType.toUpperCase()} · ${_fmtTime(result.scannedAt)}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const Spacer(),
        FilledButton.tonal(
          onPressed: _scanning ? null : _runScan,
          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
          child: _scanning
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('重新扫描'),
        ),
      ],
    );
  }

  Widget _dimensionGrid(BuildContext context, ColorScheme cs, ScanResult result) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _DimensionCard(
          dimension: AnalysisDimension.codeQuality,
          metrics: result.metrics,
          severityCounts: result.severityCounts,
        ),
        _DimensionCard(
          dimension: AnalysisDimension.securityReview,
          metrics: result.metrics,
          severityCounts: result.severityCounts,
        ),
        _DimensionCard(
          dimension: AnalysisDimension.archAnalysis,
          metrics: result.metrics,
          severityCounts: result.severityCounts,
        ),
        _DimensionCard(
          dimension: AnalysisDimension.perfAnalysis,
          metrics: result.metrics,
          severityCounts: result.severityCounts,
        ),
        _DimensionCard(
          dimension: AnalysisDimension.qualityTest,
          metrics: result.metrics,
          severityCounts: result.severityCounts,
        ),
      ],
    );
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${t.month}/${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({
    required this.dimension,
    required this.metrics,
    required this.severityCounts,
  });

  final AnalysisDimension dimension;
  final ScanMetrics metrics;
  final Map<String, int> severityCounts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (score, color) = _calcScore();
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(), size: 18, color: color),
              const SizedBox(width: 8),
              Text(dimension.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            score ?? '-',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            dimension.description,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _icon() => switch (dimension) {
        AnalysisDimension.codeQuality => Icons.code_outlined,
        AnalysisDimension.securityReview => Icons.shield_outlined,
        AnalysisDimension.archAnalysis => Icons.layers_outlined,
        AnalysisDimension.perfAnalysis => Icons.speed_outlined,
        AnalysisDimension.qualityTest => Icons.science_outlined,
      };

  (String?, Color) _calcScore() {
    switch (dimension) {
      case AnalysisDimension.codeQuality:
        final bugs = metrics.bugs ?? 0;
        final smells = metrics.codeSmells ?? 0;
        if (bugs + smells == 0) return ('A', const Color(0xFF3DAA6E));
        if (bugs + smells < 10) return ('B', const Color(0xFF6B7FD7));
        if (bugs + smells < 30) return ('C', const Color(0xFFE0A152));
        return ('D', const Color(0xFFD94F4F));
      case AnalysisDimension.securityReview:
        final vuln = metrics.vulnerabilities ?? 0;
        if (vuln == 0) return ('A', const Color(0xFF3DAA6E));
        if (vuln < 5) return ('B', const Color(0xFF6B7FD7));
        if (vuln < 15) return ('C', const Color(0xFFE0A152));
        return ('D', const Color(0xFFD94F4F));
      case AnalysisDimension.qualityTest:
        final cov = metrics.coverage;
        if (cov == null) return (null, const Color(0xFF9AA0A8));
        if (cov >= 80) return ('A', const Color(0xFF3DAA6E));
        if (cov >= 60) return ('B', const Color(0xFF6B7FD7));
        if (cov >= 40) return ('C', const Color(0xFFE0A152));
        return ('D', const Color(0xFFD94F4F));
      default:
        return ('-', const Color(0xFF9AA0A8));
    }
  }
}
