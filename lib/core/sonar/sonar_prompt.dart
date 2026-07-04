import 'sonar_report.dart';

/// 把 SonarQube 报告格式化为 claude 治理审查 prompt。
/// claude 据此产出：优先修复清单 + 质量门禁分析 + 治理路线图。
String buildSonarReviewPrompt(SonarReport r) {
  final buf = StringBuffer();
  buf.writeln('基于以下 SonarQube 扫描报告，对该项目进行代码审查与治理分析。');
  buf.writeln();
  buf.writeln('项目：`${r.projectKey}`');
  buf.writeln(
    '质量门禁：**${r.qualityGateStatus ?? '未知'}**　合计 Issues：${r.totalIssues}',
  );

  // 严重度分布（全量计数，来自 facet）
  const sevOrder = ['BLOCKER', 'CRITICAL', 'MAJOR', 'MINOR', 'INFO'];
  final parts = <String>[];
  for (final s in sevOrder) {
    final c = r.severityCounts[s];
    if (c != null && c > 0) parts.add('$s ×$c');
  }
  if (parts.isNotEmpty) buf.writeln('严重度分布：${parts.join(' / ')}');

  // 度量
  if (r.measures.isNotEmpty) {
    buf.writeln();
    buf.writeln('**度量**');
    for (final e in r.measures.entries) {
      buf.writeln('- ${e.key}: ${e.value}');
    }
  }

  // 高优 issues 表
  buf.writeln();
  buf.writeln('**需重点关注的 Issues**（已按严重度截断）');
  buf.writeln();
  buf.writeln('| 严重度 | 类型 | 文件:行 | 规则 | 说明 | 成本(min) |');
  buf.writeln('|---|---|---|---|---|---|');
  if (r.issues.isEmpty) {
    buf.writeln('| - | - | 无高优问题 | - | - | - |');
  } else {
    for (final i in r.issues) {
      final file = shortComponent(i.component, r.projectKey);
      final loc = i.line == null ? file : '$file:${i.line}';
      final msg = i.message.replaceAll('|', '\\|').replaceAll('\n', ' ');
      buf.writeln(
        '| ${i.severity} | ${i.type} | `$loc` | ${i.rule} | $msg | ${i.effort ?? '-'} |',
      );
    }
  }

  buf.writeln();
  buf.writeln('请输出：');
  buf.writeln('1. **优先修复清单**（Top 10，按 影响×修复成本 排序）：每项含 问题、根因、修复建议、涉及文件');
  buf.writeln('2. **质量门禁分析**：若门禁为 ERROR，列出未通过条件与修复路径');
  buf.writeln('3. **治理路线图**：短期（1-2 周）/ 中期（1 月）可落地改进项');
  buf.writeln('用 Markdown 表格与分级标题，聚焦可执行。');
  return buf.toString();
}

/// component 形如 "projectKey:path/to/file.dart"，裁掉项目前缀只留相对路径。
/// SonarQube component key（"projectKey:path/to/file"）→ 相对路径；公开供 sonar_file 等复用。
String shortComponent(String component, String projectKey) {
  if (projectKey.isNotEmpty && component.startsWith(projectKey)) {
    final rest = component.substring(projectKey.length);
    return rest.startsWith(':') ? rest.substring(1) : rest;
  }
  return component;
}
