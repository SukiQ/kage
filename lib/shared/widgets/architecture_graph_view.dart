import 'package:flutter/material.dart';

import '../../core/analysis/project_architecture_analyzer.dart';

/// 可视化架构图：按层级分列布局节点，CustomPaint 绘制带箭头的依赖边。
class ArchitectureGraphView extends StatelessWidget {
  const ArchitectureGraphView({super.key, required this.graph});

  final ArchitectureGraph graph;

  static const _nodeW = 168.0;
  static const _nodeH = 76.0;
  static const _colGap = 84.0;
  static const _rowGap = 20.0;
  static const _topPad = 30.0;

  static const _layerOrder = [
    '应用入口', '业务功能', '核心能力', '数据层', '共享组件', '外部系统', '模块',
  ];
  static const _layerColors = <String, Color>{
    '应用入口': Color(0xFF6B7FD7),
    '业务功能': Color(0xFF3DAA6E),
    '核心能力': Color(0xFFE0A152),
    '数据层': Color(0xFFD94F4F),
    '共享组件': Color(0xFF9AA0A8),
    '外部系统': Color(0xFFBB6BD7),
    '模块': Color(0xFF7E8AA0),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (graph.nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('架构图为空', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    final layers = _orderedLayers(graph.nodes);
    final byLayer = <String, List<ArchitectureNode>>{};
    for (final n in graph.nodes) {
      byLayer.putIfAbsent(n.layer, () => []).add(n);
    }

    final positions = <String, Offset>{};
    final byId = <String, ArchitectureNode>{for (final n in graph.nodes) n.id: n};
    for (var li = 0; li < layers.length; li++) {
      final nodes = byLayer[layers[li]]!;
      final colCenterX = li * (_nodeW + _colGap) + _nodeW / 2 + _colGap / 2;
      for (var i = 0; i < nodes.length; i++) {
        positions[nodes[i].id] =
            Offset(colCenterX, _topPad + i * (_nodeH + _rowGap) + _nodeH / 2);
      }
    }

    var maxRows = 1;
    for (final l in layers) {
      final c = byLayer[l]?.length ?? 0;
      if (c > maxRows) maxRows = c;
    }
    final totalWidth = layers.length * (_nodeW + _colGap) + _colGap / 2;
    final totalHeight = _topPad + maxRows * (_nodeH + _rowGap) + 8;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              width: totalWidth,
              height: totalHeight,
              child: CustomPaint(
                painter: _EdgePainter(positions, graph.edges, cs.outline),
              ),
            ),
            for (var li = 0; li < layers.length; li++)
              Positioned(
                left: li * (_nodeW + _colGap) + _colGap / 2,
                top: 4,
                width: _nodeW,
                child: Text(
                  layers[li],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            for (final entry in positions.entries)
              Positioned(
                left: entry.value.dx - _nodeW / 2,
                top: entry.value.dy - _nodeH / 2,
                width: _nodeW,
                height: _nodeH,
                child: _NodeCard(
                  node: byId[entry.key]!,
                  color: _colorFor(byId[entry.key]!.layer),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _orderedLayers(List<ArchitectureNode> nodes) {
    final present = <String>{for (final n in nodes) n.layer};
    final ordered = <String>[];
    for (final l in _layerOrder) {
      if (present.remove(l)) ordered.add(l);
    }
    ordered.addAll(present);
    return ordered;
  }

  Color _colorFor(String layer) => _layerColors[layer] ?? const Color(0xFF7E8AA0);
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.color});
  final ArchitectureNode node;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            node.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.positions, this.edges, this.color);
  final Map<String, Offset> positions;
  final List<ArchitectureEdge> edges;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    for (final e in edges) {
      final from = positions[e.from];
      final to = positions[e.to];
      if (from == null || to == null) continue;
      final ctrl = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
      canvas.drawPath(path, linePaint);
      _drawArrow(canvas, arrowPaint, ctrl, to);
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset ctrl, Offset tip) {
    const size = 7.0;
    final dir = tip - ctrl;
    final len = dir.distance;
    if (len == 0) return;
    final d = dir / len;
    final perp = Offset(-d.dy, d.dx);
    final p1 = tip;
    final p2 = tip - d * size + perp * size * 0.55;
    final p3 = tip - d * size - perp * size * 0.55;
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) =>
      old.positions != positions || old.edges != edges || old.color != color;
}
