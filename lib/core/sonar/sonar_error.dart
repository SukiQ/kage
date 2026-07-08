import 'package:dio/dio.dart';

/// SonarQube API 调用失败的友好错误，携带针对性提示。
class SonarApiException implements Exception {
  SonarApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// 将任意异常转换为面向用户的中文错误提示。
///
/// 常见情形：
/// - 401 → Token 无效或已过期（最常见，需在 SonarQube 重新生成）
/// - 403 → Token 无权限访问该项目
/// - 404 → 地址错误，或项目名称在 SonarQube 中不存在
/// - 网络错误 → 连接超时 / 地址不通
String describeSonarError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    switch (code) {
      case 401:
        return '认证失败（401）：SonarQube Token 无效或已过期，请在设置中重新填写 Token';
      case 403:
        return '权限不足（403）：当前 Token 无权访问该项目，请检查 Token 权限或项目名称';
      case 404:
        return '未找到（404）：地址错误或项目名称不存在，请核对 SonarQube 地址与项目名称';
      case 400:
        return '请求参数错误（400）：${e.response?.data?['errors']?.first?['msg'] ?? '请检查项目名称是否合法'}';
      case null:
        // 无响应状态码 → 连接层错误
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
          case DioExceptionType.sendTimeout:
          case DioExceptionType.receiveTimeout:
            return '连接超时：无法访问 SonarQube 服务器，请检查地址与网络';
          case DioExceptionType.connectionError:
            return '连接失败：SonarQube 地址不可达或不是有效的 HTTPS 地址';
          case DioExceptionType.badCertificate:
            return '证书错误：SonarQube 服务器的 SSL 证书不受信任';
          default:
            return '网络错误：${e.message ?? e.type.name}';
        }
      default:
        return 'SonarQube 返回错误（$code）：${e.message ?? ''}';
    }
  }
  return e.toString();
}
