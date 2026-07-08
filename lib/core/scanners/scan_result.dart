/// 扫描器统一数据模型（与具体扫描器解耦）。
library;

enum ScanSeverity { blocker, critical, major, minor, info }

enum ScanIssueType { bug, vulnerability, codeSmell, securityHotspot }

extension ScanSeverityX on ScanSeverity {
  String get label => switch (this) {
        ScanSeverity.blocker => 'BLOCKER',
        ScanSeverity.critical => 'CRITICAL',
        ScanSeverity.major => 'MAJOR',
        ScanSeverity.minor => 'MINOR',
        ScanSeverity.info => 'INFO',
      };

  int get rank => switch (this) {
        ScanSeverity.blocker => 0,
        ScanSeverity.critical => 1,
        ScanSeverity.major => 2,
        ScanSeverity.minor => 3,
        ScanSeverity.info => 4,
      };

  static ScanSeverity fromString(String s) => switch (s.toUpperCase()) {
        'BLOCKER' => ScanSeverity.blocker,
        'CRITICAL' => ScanSeverity.critical,
        'MAJOR' => ScanSeverity.major,
        'MINOR' => ScanSeverity.minor,
        _ => ScanSeverity.info,
      };
}

/// 单条扫描问题（统一格式，适配所有扫描器）。
class ScanIssue {
  const ScanIssue({
    required this.severity,
    required this.type,
    required this.component,
    required this.line,
    required this.rule,
    required this.message,
    required this.scannerType,
    this.effort,
  });

  final ScanSeverity severity;
  final ScanIssueType type;

  /// 文件路径（相对于项目根目录）
  final String component;
  final int? line;
  final String rule;
  final String message;

  /// 来源扫描器标识，如 'sonarqube'、'eslint'
  final String scannerType;

  /// 预估修复成本（可为 null）
  final String? effort;

  String get key => '$component:${line ?? 0}:$rule';

  ScanIssue copyWith({
    ScanSeverity? severity,
    ScanIssueType? type,
    String? component,
    int? line,
    String? rule,
    String? message,
    String? scannerType,
    String? effort,
  }) => ScanIssue(
        severity: severity ?? this.severity,
        type: type ?? this.type,
        component: component ?? this.component,
        line: line ?? this.line,
        rule: rule ?? this.rule,
        message: message ?? this.message,
        scannerType: scannerType ?? this.scannerType,
        effort: effort ?? this.effort,
      );
}

/// 质量指标快照（各扫描器尽力填充，不支持的字段置 null）。
class ScanMetrics {
  const ScanMetrics({
    this.bugs,
    this.vulnerabilities,
    this.codeSmells,
    this.securityHotspots,
    this.coverage,
    this.duplicatedLinesDensity,
    this.technicalDebtMinutes,
    this.reliabilityRating,
    this.securityRating,
    this.maintainabilityRating,
  });

  final int? bugs;
  final int? vulnerabilities;
  final int? codeSmells;
  final int? securityHotspots;
  final double? coverage;
  final double? duplicatedLinesDensity;
  final int? technicalDebtMinutes;

  /// A/B/C/D/E
  final String? reliabilityRating;
  final String? securityRating;
  final String? maintainabilityRating;

  static const empty = ScanMetrics();

  Map<String, String> toDisplayMap() {
    final m = <String, String>{};
    if (bugs != null) m['Bugs'] = '$bugs';
    if (vulnerabilities != null) m['漏洞'] = '$vulnerabilities';
    if (codeSmells != null) m['代码异味'] = '$codeSmells';
    if (securityHotspots != null) m['安全热点'] = '$securityHotspots';
    if (coverage != null) m['覆盖率'] = '${coverage!.toStringAsFixed(1)}%';
    if (duplicatedLinesDensity != null) m['重复行'] = '${duplicatedLinesDensity!.toStringAsFixed(1)}%';
    return m;
  }
}

/// 扫描结果（单次扫描的完整输出）。
class ScanResult {
  const ScanResult({
    required this.projectKey,
    required this.scannerType,
    required this.scannedAt,
    required this.issues,
    required this.metrics,
    required this.severityCounts,
    this.qualityGateStatus,
    this.totalIssues,
  });

  final String projectKey;
  final String scannerType;
  final DateTime scannedAt;

  /// 高优问题（已截断，BLOCKER/CRITICAL 全量，MAJOR Top 30）
  final List<ScanIssue> issues;

  final ScanMetrics metrics;

  /// severity label -> count（全量，来自 facet 或聚合）
  final Map<String, int> severityCounts;

  /// 质量门禁状态：OK / ERROR / null（不支持时）
  final String? qualityGateStatus;

  /// 全量问题数（未截断）
  final int? totalIssues;

  bool get isEmpty => (totalIssues ?? issues.length) == 0 && metrics == ScanMetrics.empty;

  bool get passed => qualityGateStatus == 'OK';
}
