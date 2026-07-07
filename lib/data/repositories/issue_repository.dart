import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/issue_record.dart';
import '../../core/scanners/scan_result.dart';

/// Issue 生命周期仓库：本地 JSON 持久化，按项目分文件存储。
class IssueRepository {
  IssueRepository._(this._dir);

  final Directory _dir;

  static Future<IssueRepository> create() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'Kage', 'issues'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return IssueRepository._(dir);
  }

  File _file(String projectId) => File(p.join(_dir.path, '$projectId.json'));

  Future<List<IssueRecord>> forProject(String projectId) async {
    final f = _file(projectId);
    if (!f.existsSync()) return [];
    try {
      final list = jsonDecode(await f.readAsString()) as List;
      return list.map((e) => IssueRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(String projectId, List<IssueRecord> records) async {
    await _file(projectId).writeAsString(
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }

  /// 将扫描结果同步到本地记录：新 issue 创建为 open，已有的保留当前状态。
  Future<List<IssueRecord>> syncFromScan(
    String projectId,
    List<ScanIssue> issues,
  ) async {
    final existing = await forProject(projectId);
    final existingMap = {for (final r in existing) r.issueKey: r};
    final now = DateTime.now();

    final merged = issues.map((issue) {
      final key = issue.key;
      final found = existingMap[key];
      if (found != null) return found; // 保留已有生命周期状态
      return IssueRecord(
        id: '${projectId}_${key.hashCode.abs()}',
        projectId: projectId,
        scannerType: issue.scannerType,
        issueKey: key,
        severity: issue.severity.label,
        type: issue.type.name,
        component: issue.component,
        line: issue.line,
        rule: issue.rule,
        message: issue.message,
        effort: issue.effort,
        status: IssueStatus.open,
        createdAt: now,
        updatedAt: now,
      );
    }).toList();

    await _persist(projectId, merged);
    return merged;
  }

  Future<void> updateStatus(
    String projectId,
    String issueKey,
    IssueStatus status, {
    String? comment,
  }) async {
    final records = await forProject(projectId);
    final idx = records.indexWhere((r) => r.issueKey == issueKey);
    if (idx < 0) return;
    records[idx] = records[idx].copyWith(status: status, comment: comment);
    await _persist(projectId, records);
  }

  /// 批量将指定 issue 标记为已修复（一次读取→批量改→一次持久化）。
  Future<void> markFixed(
    String projectId,
    List<String> issueKeys, {
    String? comment,
  }) async {
    if (issueKeys.isEmpty) return;
    final records = await forProject(projectId);
    final keySet = issueKeys.toSet();
    var changed = false;
    for (var i = 0; i < records.length; i++) {
      if (keySet.contains(records[i].issueKey) &&
          records[i].status != IssueStatus.fixed) {
        records[i] = records[i].copyWith(
          status: IssueStatus.fixed,
          comment: comment ?? records[i].comment,
        );
        changed = true;
      }
    }
    if (changed) await _persist(projectId, records);
  }

  Future<void> updateAssignee(
    String projectId,
    String issueKey,
    String? assignee,
  ) async {
    final records = await forProject(projectId);
    final idx = records.indexWhere((r) => r.issueKey == issueKey);
    if (idx < 0) return;
    records[idx] = records[idx].copyWith(assignee: assignee);
    await _persist(projectId, records);
  }

  /// 清除项目所有已过期记录（状态为 fixed/ignored 且超过 days 天）
  Future<void> purgeResolved(String projectId, {int days = 30}) async {
    final records = await forProject(projectId);
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final kept = records.where((r) {
      if (r.status == IssueStatus.open || r.status == IssueStatus.inProgress) return true;
      return r.updatedAt.isAfter(cutoff);
    }).toList();
    await _persist(projectId, kept);
  }
}
