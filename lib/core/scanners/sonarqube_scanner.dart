import 'dart:convert';
import 'dart:io';

import '../sonar/sonar_client.dart';
import '../storage/settings_service.dart';
import '../../data/models/project.dart';
import 'scan_result.dart';
import 'scanner.dart';

/// 将现有 SonarClient 适配为统一 Scanner 接口。
/// scan 流程：先执行 sonar-scanner CLI（如项目配置了），再拉取报告。
/// 项目名称（project.name）即作为 SonarQube project key。
class SonarQubeScanner extends Scanner {
  SonarQubeScanner(this._settings);

  final SettingsService _settings;

  /// 子进程环境缓存。登录 shell 解析较慢，结果缓存避免每次扫描都启动 shell。
  Map<String, String>? _envCache;

  /// CLI 扫描最长等待时间（首次运行需下载 sonar 插件，给足时间）。
  static const _cliTimeout = Duration(minutes: 15);

  @override
  String get type => 'sonarqube';

  @override
  String get displayName => 'SonarQube';

  @override
  String? validate(KageProject project) {
    if (_settings.sonarHost?.isEmpty ?? true) return 'SonarQube 地址未配置';
    if (_settings.sonarToken?.isEmpty ?? true) return 'SonarQube Token 未配置';
    return null;
  }

  // ── 步骤1：触发服务端扫描 ────────────────────────────────────────────────

  @override
  Future<void> triggerScan(
    KageProject project, {
    ScanProgressCallback? onProgress,
  }) async {
    final propsFile = File('${project.path}${Platform.pathSeparator}sonar-project.properties');
    final hasProps = propsFile.existsSync();

    // 检测可用的 CLI 工具
    final cli = await _detectScannerCli(project.path);
    if (cli == null && !hasProps) {
      // 没有 CLI 也没有配置文件，跳过触发（只拉报告）
      onProgress?.call('未找到 sonar-scanner，直接拉取已有报告…');
      return;
    }
    if (cli == null) {
      onProgress?.call('未找到 sonar-scanner CLI，直接拉取已有报告…');
      return;
    }

    onProgress?.call('执行 ${cli.displayName} 扫描中…');

    Process? process;
    try {
      final env = await _buildEnv();
      process = await Process.start(
        cli.executable,
        [
          ...cli.args,
          '-Dsonar.host.url=${_settings.sonarHost}',
          '-Dsonar.token=${_settings.sonarToken}',
          '-Dsonar.projectKey=${project.name}',
        ],
        workingDirectory: project.path,
        runInShell: true,
        environment: env,
      );

      // 留存输出用于失败诊断（Maven/Gradle 错误日志走 stdout 的 [ERROR] 行，stderr 常为空）
      final stdoutLines = <String>[];
      final stderrBuf = StringBuffer();
      process.stdout
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen(stdoutLines.add);
      process.stderr
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen((line) => stderrBuf.writeln(line));

      final exitCode = await process.exitCode.timeout(
        _cliTimeout,
        onTimeout: () {
          process!.kill();
          throw Exception('${cli.displayName} 扫描超时（${_cliTimeout.inMinutes} 分钟无响应），已终止。请检查网络或 SonarQube 服务是否可达');
        },
      );
      if (exitCode != 0) {
        final detail = _extractFailure(stdoutLines, stderrBuf.toString());
        throw Exception('扫描失败（${cli.displayName} 退出码 $exitCode）：\n$detail');
      }

      onProgress?.call('扫描完成，等待服务端处理…');
      // 等待 SonarQube 后台任务处理完毕
      await _waitForAnalysis(project.name, onProgress: onProgress);
    } catch (e) {
      process?.kill();
      if (e is ProcessException) {
        throw Exception('${cli.displayName} 启动失败：${e.message}');
      }
      rethrow;
    }
  }

  // ── 步骤2：拉取报告 ──────────────────────────────────────────────────────

  @override
  Future<ScanResult> fetchResult(KageProject project) async {
    final client = SonarClient(
      host: _settings.sonarHost!,
      token: _settings.sonarToken!,
    );
    final report = await client.fetchReport(project.name);

    final issues = report.issues.map((i) => ScanIssue(
      severity: ScanSeverityX.fromString(i.severity),
      type: _mapType(i.type),
      component: i.component,
      line: i.line,
      rule: i.rule,
      message: i.message,
      scannerType: type,
      effort: i.effort,
    )).toList();

    final m = report.measures;
    final metrics = ScanMetrics(
      bugs: int.tryParse(m['bugs'] ?? ''),
      vulnerabilities: int.tryParse(m['vulnerabilities'] ?? ''),
      codeSmells: int.tryParse(m['code_smells'] ?? ''),
      securityHotspots: int.tryParse(m['security_hotspots'] ?? ''),
      coverage: double.tryParse(m['coverage'] ?? ''),
      duplicatedLinesDensity: double.tryParse(m['duplicated_lines_density'] ?? ''),
      technicalDebtMinutes: int.tryParse(m['sqale_index'] ?? ''),
      reliabilityRating: _letterRating(m['reliability_rating']),
      securityRating: _letterRating(m['security_rating']),
      maintainabilityRating: _letterRating(m['sqale_rating']),
    );

    return ScanResult(
      projectKey: project.name,
      scannerType: type,
      scannedAt: DateTime.now(),
      issues: issues,
      metrics: metrics,
      severityCounts: report.severityCounts,
      qualityGateStatus: report.qualityGateStatus,
      totalIssues: report.totalIssues,
    );
  }

  // ── 工具方法 ─────────────────────────────────────────────────────────────

  /// 构建子进程环境变量。
  ///
  /// macOS/Linux 上，从 GUI/IDE 启动的进程不会加载登录 shell 配置
  /// （~/.bash_profile、~/.zshrc 等），其 PATH 仅含系统默认目录，不含
  /// mvn/gradle/java 等，导致 `mvn: command not found`（退出码 127）。
  /// 这里通过登录 shell 解析出真实 PATH 并合并进来，结果缓存。
  Future<Map<String, String>> _buildEnv() async {
    if (_envCache != null) return _envCache!;
    final env = Map<String, String>.from(Platform.environment);
    if (!Platform.isWindows) {
      final loginPath = await _resolveLoginPath();
      if (loginPath.isNotEmpty) {
        final base = env['PATH'] ?? '';
        final seen = <String>{};
        final merged = <String>[];
        for (final p in [...base.split(':'), ...loginPath.split(':')]) {
          if (p.isNotEmpty && seen.add(p)) merged.add(p);
        }
        env['PATH'] = merged.join(':');
      }
    }
    _envCache = env;
    return env;
  }

  /// 用登录 shell 解析 PATH：bash 加载 ~/.bash_profile，zsh 交互登录加载
  /// ~/.zprofile + ~/.zshrc。两者 PATH 取并集，覆盖常见配置位置。
  Future<String> _resolveLoginPath() async {
    final buffers = <String>[];
    Future<void> probe(String exe, List<String> args) async {
      try {
        final r = await Process.run(exe, args);
        final out = (r.stdout as String).trim();
        if (out.isNotEmpty) buffers.add(out);
      } catch (_) {}
    }

    await probe('/bin/bash', ['-l', '-c', r'printf "%s" "$PATH"']);
    if (Platform.isMacOS) {
      await probe('/bin/zsh', ['-lic', r'printf "%s" "$PATH"']);
    }
    return buffers.join(':');
  }

  /// 检测项目目录下可用的 sonar-scanner CLI
  Future<_CliInfo?> _detectScannerCli(String projectPath) async {
    // Maven 项目：优先用项目自带 wrapper（Unix: mvnw / Windows: mvnw.cmd）
    final mvnw = File('$projectPath${Platform.pathSeparator}mvnw');
    final mvnwCmd = File('$projectPath${Platform.pathSeparator}mvnw.cmd');
    final pom = File('$projectPath${Platform.pathSeparator}pom.xml');
    if (pom.existsSync()) {
      final hasWrapper = Platform.isWindows ? mvnwCmd.existsSync() : mvnw.existsSync();
      final exe = hasWrapper ? (Platform.isWindows ? mvnwCmd.path : mvnw.path) : 'mvn';
      return _CliInfo(exe, ['sonar:sonar'], 'Maven Sonar');
    }

    // Gradle 项目：优先用项目自带 wrapper（Unix: gradlew / Windows: gradlew.bat）
    final gradlew = File('$projectPath${Platform.pathSeparator}gradlew');
    final gradlewBat = File('$projectPath${Platform.pathSeparator}gradlew.bat');
    final gradleGroovy = File('$projectPath${Platform.pathSeparator}build.gradle');
    final gradleKts = File('$projectPath${Platform.pathSeparator}build.gradle.kts');
    if (gradleGroovy.existsSync() || gradleKts.existsSync()) {
      final hasWrapper = Platform.isWindows ? gradlewBat.existsSync() : gradlew.existsSync();
      final exe = hasWrapper ? (Platform.isWindows ? gradlewBat.path : gradlew.path) : 'gradlew';
      return _CliInfo(exe, ['sonarqube'], 'Gradle Sonar');
    }

    // 通用 sonar-scanner（Windows: where / Unix: which），同样需要补全 PATH
    final lookup = Platform.isWindows ? 'where' : 'which';
    final r = await Process.run(lookup, ['sonar-scanner'],
        runInShell: true, environment: await _buildEnv());
    if (r.exitCode == 0) {
      return _CliInfo('sonar-scanner', [], 'sonar-scanner');
    }

    return null;
  }

  /// 轮询 SonarQube /api/ce/component 直到分析完成（最多等 120s）
  Future<void> _waitForAnalysis(
    String projectKey, {
    ScanProgressCallback? onProgress,
    int maxRetries = 24,
    Duration interval = const Duration(seconds: 5),
  }) async {
    for (var i = 0; i < maxRetries; i++) {
      await Future.delayed(interval);
      try {
        final client = SonarClient(
          host: _settings.sonarHost!,
          token: _settings.sonarToken!,
        );
        final status = await client.fetchAnalysisStatus(projectKey);
        if (status == 'SUCCESS' || status == 'FAILED' || status == null) {
          if (status == 'FAILED') throw Exception('SonarQube 分析失败（服务端）');
          onProgress?.call('服务端分析完成，正在拉取报告…');
          return;
        }
        onProgress?.call('服务端分析中… (${(i + 1) * 5}s)');
      } catch (e) {
        if (e.toString().contains('分析失败')) rethrow;
        // 网络抖动忽略，继续轮询
      }
    }
    onProgress?.call('等待超时，直接拉取当前报告…');
  }

  /// 从 CLI 输出中提取失败原因。
  /// Maven/Gradle 的错误日志走 stdout 的 [ERROR]/ERROR 行，stderr 常为空。
  String _extractFailure(List<String> stdout, String stderr) {
    String clean(String l) => l.split('\r').last.trim();
    final errors = stdout
        .map(clean)
        .where((l) => l.startsWith('[ERROR]') || l.startsWith('ERROR '))
        .toList();
    if (errors.isNotEmpty) return errors.take(6).join('\n');
    final err = stderr.trim();
    if (err.isNotEmpty) return err;
    final tail = stdout.map(clean).where((l) => l.isNotEmpty).toList();
    if (tail.isEmpty) return '（无输出）';
    return tail.take(10).join('\n');
  }

  ScanIssueType _mapType(String t) => switch (t.toUpperCase()) {
    'BUG' => ScanIssueType.bug,
    'VULNERABILITY' => ScanIssueType.vulnerability,
    'SECURITY_HOTSPOT' => ScanIssueType.securityHotspot,
    _ => ScanIssueType.codeSmell,
  };

  String? _letterRating(String? v) {
    if (v == null) return null;
    return switch (v.split('.').first) {
      '1' => 'A', '2' => 'B', '3' => 'C', '4' => 'D', _ => 'E',
    };
  }
}

class _CliInfo {
  const _CliInfo(this.executable, this.args, this.displayName);
  final String executable;
  final List<String> args;
  final String displayName;
}
