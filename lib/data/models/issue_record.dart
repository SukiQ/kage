/// Issue 处理状态流转：open → inProgress → fixed / ignored / falsePositive
enum IssueStatus { open, inProgress, fixed, ignored, falsePositive }

extension IssueStatusX on IssueStatus {
  String get label => switch (this) {
        IssueStatus.open => '待处理',
        IssueStatus.inProgress => '处理中',
        IssueStatus.fixed => '已修复',
        IssueStatus.ignored => '已忽略',
        IssueStatus.falsePositive => '误报',
      };

  String get value => name;

  static IssueStatus fromString(String s) =>
      IssueStatus.values.firstWhere((e) => e.name == s, orElse: () => IssueStatus.open);
}

/// 本地 Issue 生命周期记录（覆盖 ScanIssue 的状态、优先级、指派人）。
class IssueRecord {
  IssueRecord({
    required this.id,
    required this.projectId,
    required this.scannerType,
    required this.issueKey,
    required this.severity,
    required this.type,
    required this.component,
    required this.line,
    required this.rule,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.effort,
    this.assignee,
    this.comment,
  });

  final String id;
  final String projectId;
  final String scannerType;

  /// 等同 ScanIssue.key（component:line:rule），跨扫描保持稳定
  final String issueKey;

  final String severity;
  final String type;
  final String component;
  final int? line;
  final String rule;
  final String message;
  final String? effort;

  IssueStatus status;
  String? assignee;
  String? comment;

  final DateTime createdAt;
  DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'projectId': projectId,
        'scannerType': scannerType,
        'issueKey': issueKey,
        'severity': severity,
        'type': type,
        'component': component,
        'line': line,
        'rule': rule,
        'message': message,
        'effort': effort,
        'status': status.value,
        'assignee': assignee,
        'comment': comment,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory IssueRecord.fromJson(Map<String, dynamic> j) => IssueRecord(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        scannerType: j['scannerType'] as String? ?? 'sonarqube',
        issueKey: j['issueKey'] as String,
        severity: j['severity'] as String,
        type: j['type'] as String? ?? 'CODE_SMELL',
        component: j['component'] as String,
        line: j['line'] as int?,
        rule: j['rule'] as String,
        message: j['message'] as String,
        effort: j['effort'] as String?,
        status: IssueStatusX.fromString(j['status'] as String? ?? 'open'),
        assignee: j['assignee'] as String?,
        comment: j['comment'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );

  IssueRecord copyWith({IssueStatus? status, String? assignee, String? comment}) {
    final r = IssueRecord(
      id: id,
      projectId: projectId,
      scannerType: scannerType,
      issueKey: issueKey,
      severity: severity,
      type: type,
      component: component,
      line: line,
      rule: rule,
      message: message,
      effort: effort,
      status: status ?? this.status,
      assignee: assignee ?? this.assignee,
      comment: comment ?? this.comment,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
    return r;
  }
}
