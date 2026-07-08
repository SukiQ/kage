/// 性能分析报告数据模型（由 AI 阅读项目代码后输出的 JSON 解析而来）。
class PerformanceReport {
  const PerformanceReport({
    required this.summary,
    required this.overall,
    required this.issues,
    required this.suggestions,
  });

  /// 整体性能评估一句话。
  final String summary;

  /// 整体严重度：critical / high / medium / low / good。
  final String overall;

  /// 性能问题列表。
  final List<PerformanceIssue> issues;

  /// 系统性优化建议。
  final List<String> suggestions;

  factory PerformanceReport.fromJson(Map<String, dynamic> json) {
    return PerformanceReport(
      summary: json['summary']?.toString() ?? '',
      overall: json['overall']?.toString() ?? 'medium',
      issues: (json['issues'] as List? ?? [])
          .whereType<Map>()
          .map((e) => PerformanceIssue.fromJson(e.cast<String, dynamic>()))
          .toList(),
      suggestions: (json['suggestions'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}

class PerformanceIssue {
  const PerformanceIssue({
    required this.category,
    required this.severity,
    required this.file,
    required this.line,
    required this.title,
    required this.description,
    required this.suggestion,
    required this.impact,
  });

  /// 算法复杂度 / 数据库性能 / 内存与GC / 并发与锁 / I/O瓶颈 / 资源使用。
  final String category;

  /// critical / high / medium / low。
  final String severity;

  final String file;
  final int? line;
  final String title;
  final String description;
  final String suggestion;

  /// 影响程度：high / medium / low。
  final String impact;

  factory PerformanceIssue.fromJson(Map<String, dynamic> json) => PerformanceIssue(
        category: json['category']?.toString() ?? '资源使用',
        severity: json['severity']?.toString() ?? 'medium',
        file: json['file']?.toString() ?? '',
        line: json['line'] is int ? json['line'] as int : null,
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        suggestion: json['suggestion']?.toString() ?? '',
        impact: json['impact']?.toString() ?? 'medium',
      );
}
