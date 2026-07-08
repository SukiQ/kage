/// 架构图数据模型（由 AI 分析项目代码后输出的 JSON 解析而来）。
///
/// 历史上有本地确定性扫描器（ProjectArchitectureAnalyzer）产出这些模型，
/// 现已移除——架构分析完全交由 AI 阅读代码生成。文件名保留以避免大范围 import 改动。
class ArchitectureGraph {
  const ArchitectureGraph({
    required this.nodes,
    required this.edges,
    required this.summary,
    required this.developmentHints,
    this.localFallback = false,
  });

  final List<ArchitectureNode> nodes;
  final List<ArchitectureEdge> edges;
  final String summary;
  final List<String> developmentHints;
  final bool localFallback;

  factory ArchitectureGraph.fromJson(Map<String, dynamic> json) {
    return ArchitectureGraph(
      nodes: (json['nodes'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ArchitectureNode.fromJson(e.cast<String, dynamic>()))
          .toList(),
      edges: (json['edges'] as List? ?? [])
          .whereType<Map>()
          .map((e) => ArchitectureEdge.fromJson(e.cast<String, dynamic>()))
          .toList(),
      summary: json['summary']?.toString() ?? '',
      developmentHints: (json['developmentHints'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}

class ArchitectureNode {
  const ArchitectureNode({
    required this.id,
    required this.label,
    required this.layer,
    required this.description,
  });

  final String id;
  final String label;
  final String layer;
  final String description;

  factory ArchitectureNode.fromJson(Map<String, dynamic> json) => ArchitectureNode(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        layer: json['layer']?.toString() ?? '模块',
        description: json['description']?.toString() ?? '',
      );
}

class ArchitectureEdge {
  const ArchitectureEdge({
    required this.from,
    required this.to,
    required this.label,
    this.weight = 1,
  });

  final String from;
  final String to;
  final String label;
  final int weight;

  factory ArchitectureEdge.fromJson(Map<String, dynamic> json) => ArchitectureEdge(
        from: json['from']?.toString() ?? '',
        to: json['to']?.toString() ?? '',
        label: json['label']?.toString() ?? '依赖',
        weight: json['weight'] is int ? json['weight'] as int : 1,
      );
}
