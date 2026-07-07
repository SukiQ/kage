import '../../core/analysis/analysis_dimension.dart';

/// 单次 AI 分析会话中 Claude 返回的一条发现
class AnalysisFinding {
  const AnalysisFinding({
    required this.title,
    required this.severity,
    required this.description,
    this.location,
    this.suggestion,
  });

  final String title;
  // critical / high / medium / low / info
  final String severity;
  final String description;
  final String? location;
  final String? suggestion;

  Map<String, dynamic> toJson() => {
        'title': title,
        'severity': severity,
        'description': description,
        if (location != null) 'location': location,
        if (suggestion != null) 'suggestion': suggestion,
      };

  factory AnalysisFinding.fromJson(Map<String, dynamic> j) => AnalysisFinding(
        title: j['title'] as String,
        severity: j['severity'] as String? ?? 'info',
        description: j['description'] as String,
        location: j['location'] as String?,
        suggestion: j['suggestion'] as String?,
      );
}

/// 单个维度的分析报告（每次运行扫描后可生成）
class AnalysisReport {
  AnalysisReport({
    required this.id,
    required this.projectId,
    required this.dimension,
    required this.scannedAt,
    this.score,
    this.rating,
    this.summary,
    this.aiInsights,
    this.findings = const [],
  });

  final String id;
  final String projectId;
  final AnalysisDimension dimension;
  final DateTime scannedAt;

  /// 0-100 分，null 表示尚未 AI 评分
  final double? score;

  /// A/B/C/D/E
  final String? rating;

  /// 一句话摘要
  final String? summary;

  /// AI 深度分析全文（Markdown）
  final String? aiInsights;

  final List<AnalysisFinding> findings;

  String get ratingLabel => rating ?? (score == null ? '-' : _scoreToRating(score!));

  static String _scoreToRating(double s) {
    if (s >= 90) return 'A';
    if (s >= 75) return 'B';
    if (s >= 60) return 'C';
    if (s >= 40) return 'D';
    return 'E';
  }

  AnalysisReport copyWith({
    String? aiInsights,
    double? score,
    String? rating,
    String? summary,
    List<AnalysisFinding>? findings,
  }) => AnalysisReport(
        id: id,
        projectId: projectId,
        dimension: dimension,
        scannedAt: scannedAt,
        score: score ?? this.score,
        rating: rating ?? this.rating,
        summary: summary ?? this.summary,
        aiInsights: aiInsights ?? this.aiInsights,
        findings: findings ?? this.findings,
      );
}
