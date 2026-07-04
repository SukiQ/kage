/// SonarQube 单条问题。
class SonarIssue {
  const SonarIssue({
    required this.severity,
    required this.type,
    required this.component,
    required this.line,
    required this.rule,
    required this.message,
    required this.effort,
  });

  /// BLOCKER / CRITICAL / MAJOR / MINOR / INFO
  final String severity;

  /// BUG / VULNERABILITY / CODE_SMELL / SECURITY_HOTSPOT
  final String type;

  /// 文件组件 key（含项目前缀，展示时可裁剪）
  final String component;
  final int? line;
  final String rule;
  final String message;

  /// 修复成本（分钟，字符串）
  final String? effort;
}

/// SonarQube 项目扫描报告（已按严重度截断高优 issues，全量计数来自 facet）。
class SonarReport {
  const SonarReport({
    required this.issues,
    required this.measures,
    required this.qualityGateStatus,
    required this.totalIssues,
    required this.severityCounts,
    required this.projectKey,
  });

  /// 已截断的高优 issues（BLOCKER/CRITICAL 全留、MAJOR Top 30）
  final List<SonarIssue> issues;

  /// metric -> value（bugs/vulnerabilities/code_smells/coverage/...）
  final Map<String, String> measures;

  /// OK / ERROR / null
  final String? qualityGateStatus;

  /// 全量 issue 计数（未截断）
  final int totalIssues;

  /// severity -> 全量计数（来自 facet）
  final Map<String, int> severityCounts;
  final String projectKey;

  bool get isEmpty => totalIssues == 0 && measures.isEmpty;
}
