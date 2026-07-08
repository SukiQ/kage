import '../../data/models/project.dart';
import 'scan_result.dart';

/// 扫描进度回调
typedef ScanProgressCallback = void Function(String message);

/// 扫描器抽象接口——所有具体扫描器（SonarQube、ESLint 等）实现此接口。
abstract class Scanner {
  String get type;
  String get displayName;

  /// 校验配置是否完整（返回 null 表示就绪，否则返回错误原因）
  String? validate(KageProject project);

  /// 触发服务端扫描（运行 CLI 工具）。
  /// 实现类不支持时可直接返回（留空）。
  Future<void> triggerScan(
    KageProject project, {
    ScanProgressCallback? onProgress,
  }) async {}

  /// 从服务端拉取最新报告（扫描结果）。
  Future<ScanResult> fetchResult(KageProject project);

  /// 一步完成：先触发扫描，再拉取报告。
  Future<ScanResult> scan(
    KageProject project, {
    ScanProgressCallback? onProgress,
  }) async {
    await triggerScan(project, onProgress: onProgress);
    return fetchResult(project);
  }
}
