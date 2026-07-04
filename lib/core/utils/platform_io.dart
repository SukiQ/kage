import 'dart:io';

class PlatformIo {
  static bool get isWindows => Platform.isWindows;

  static bool get isMacOS => Platform.isMacOS;

  static String? get homeDir {
    if (Platform.isWindows) return Platform.environment['USERPROFILE'];
    return Platform.environment['HOME'];
  }
}
