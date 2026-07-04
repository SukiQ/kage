import 'dart:convert';

import 'package:dio/dio.dart';

import 'sonar_report.dart';

/// 调用 SonarQube REST API 拉取项目扫描报告。
/// 认证用 Basic Auth（`token:`）。错误由上层 catch 后降级为纯 claude 审查。
class SonarClient {
  SonarClient({required this.host, required this.token});

  final String host;
  final String token;

  Dio _dio() {
    final creds = base64Encode(utf8.encode('$token:'));
    return Dio(
      BaseOptions(
        baseUrl: host.replaceAll(RegExp(r'/+$'), ''),
        headers: {'Authorization': 'Basic $creds'},
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );
  }

  /// 拉取完整报告：issues（截断）+ measures + 质量门禁。
  Future<SonarReport> fetchReport(String projectKey) async {
    final dio = _dio();
    final issues = await _fetchIssues(dio, projectKey);
    final measures = await _fetchMeasures(dio, projectKey);
    final qg = await _fetchQualityGate(dio, projectKey);
    return SonarReport(
      issues: issues.kept,
      measures: measures,
      qualityGateStatus: qg,
      totalIssues: issues.total,
      severityCounts: issues.severityCounts,
      projectKey: projectKey,
    );
  }

  Future<_IssuesResult> _fetchIssues(Dio dio, String key) async {
    final res = await dio.get(
      '/api/issues/search',
      queryParameters: {
        'componentKeys': key,
        'ps': 500,
        'facets': 'severities,types',
        's': 'FILE_DIR',
      },
    );
    final data = res.data as Map<String, dynamic>;
    final list = (data['issues'] as List? ?? []).cast<Map<String, dynamic>>();
    final total =
        (data['paging'] as Map<String, dynamic>?)?['total'] as int? ??
        list.length;

    // 全量 severity 计数（来自 facet）
    final severityCounts = <String, int>{};
    for (final f
        in (data['facets'] as List? ?? []).cast<Map<String, dynamic>>()) {
      if (f['property'] == 'severities') {
        for (final v
            in (f['values'] as List? ?? []).cast<Map<String, dynamic>>()) {
          severityCounts[v['val'] as String] = v['count'] as int;
        }
      }
    }

    // 截断：BLOCKER/CRITICAL 全留，MAJOR Top 30，其余不进 kept
    final kept = <SonarIssue>[];
    var major = 0;
    for (final m in list) {
      final sev = (m['severity'] as String?) ?? 'MAJOR';
      final issue = SonarIssue(
        severity: sev,
        type: (m['type'] as String?) ?? 'CODE_SMELL',
        component: (m['component'] as String?) ?? '',
        line: m['line'] as int?,
        rule: (m['rule'] as String?) ?? '',
        message: (m['message'] as String?) ?? '',
        effort: m['effort'] as String?,
      );
      if (sev == 'BLOCKER' || sev == 'CRITICAL') {
        kept.add(issue);
      } else if (sev == 'MAJOR' && major < 30) {
        kept.add(issue);
        major++;
      }
    }
    // 按严重度排序展示
    kept.sort((a, b) => _severityRank(a.severity) - _severityRank(b.severity));
    return _IssuesResult(kept, severityCounts, total);
  }

  Future<Map<String, String>> _fetchMeasures(Dio dio, String key) async {
    try {
      final res = await dio.get(
        '/api/measures/component',
        queryParameters: {
          'component': key,
          'metricKeys':
              'bugs,vulnerabilities,code_smells,security_hotspots,coverage,duplicated_lines_density,sqale_index,reliability_rating,security_rating,sqale_rating',
        },
      );
      final measures = (res.data['component']?['measures'] as List? ?? []);
      final out = <String, String>{};
      for (final e in measures) {
        final m = e as Map<String, dynamic>;
        final v = m['value'] ?? m['period']?['value'];
        out[m['metric'] as String] = v?.toString() ?? '';
      }
      return out;
    } on DioException {
      return {};
    }
  }

  Future<String?> _fetchQualityGate(Dio dio, String key) async {
    try {
      final res = await dio.get(
        '/api/qualitygates/project_status',
        queryParameters: {'projectKey': key},
      );
      return res.data['projectStatus']?['status'] as String?;
    } on DioException {
      return null;
    }
  }

  int _severityRank(String s) => switch (s) {
    'BLOCKER' => 0,
    'CRITICAL' => 1,
    'MAJOR' => 2,
    'MINOR' => 3,
    _ => 4,
  };
}

class _IssuesResult {
  final List<SonarIssue> kept;
  final Map<String, int> severityCounts;
  final int total;

  const _IssuesResult(this.kept, this.severityCounts, this.total);
}
