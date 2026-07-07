/// 测试计划报告数据模型（由 AI 分析现有代码和测试后输出的 JSON 解析而来）。
class TestPlanReport {
  const TestPlanReport({
    required this.summary,
    required this.coverageGaps,
    required this.recommendedCases,
    required this.suggestions,
  });

  /// 整体测试质量评估一句话。
  final String summary;

  /// 覆盖率缺口。
  final TestCoverageGaps coverageGaps;

  /// AI 推荐的测试用例列表。
  final List<RecommendedTestCase> recommendedCases;

  /// 系统性测试改进建议。
  final List<String> suggestions;

  factory TestPlanReport.fromJson(Map<String, dynamic> json) {
    return TestPlanReport(
      summary: json['summary']?.toString() ?? '',
      coverageGaps: json['coverageGaps'] is Map
          ? TestCoverageGaps.fromJson((json['coverageGaps'] as Map).cast<String, dynamic>())
          : TestCoverageGaps.empty,
      recommendedCases: (json['recommendedCases'] as List? ?? [])
          .whereType<Map>()
          .map((e) => RecommendedTestCase.fromJson(e.cast<String, dynamic>()))
          .toList(),
      suggestions: (json['suggestions'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}

class TestCoverageGaps {
  const TestCoverageGaps({
    required this.overallCoverage,
    required this.highRiskModules,
  });

  /// 整体覆盖率估算，0~1。
  final double overallCoverage;

  /// 覆盖率不足的高风险模块路径。
  final List<String> highRiskModules;

  static const empty = TestCoverageGaps(overallCoverage: 0, highRiskModules: []);

  factory TestCoverageGaps.fromJson(Map<String, dynamic> json) {
    final cov = json['overallCoverage'];
    return TestCoverageGaps(
      overallCoverage: cov is num ? cov.toDouble() : 0,
      highRiskModules: (json['highRiskModules'] as List? ?? [])
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}

class RecommendedTestCase {
  const RecommendedTestCase({
    required this.module,
    required this.priority,
    required this.category,
    required this.scenario,
    required this.description,
    required this.testType,
    required this.whyImportant,
  });

  /// 模块路径（如 lib/features/auth/login_form.dart）。
  final String module;

  /// 优先级：critical / high / medium / low。
  final String priority;

  /// 测试类别：边界值 / 异常流程 / 状态转换 / 并发场景 / 性能压力 / 安全漏洞。
  final String category;

  /// 测试场景标题。
  final String scenario;

  /// 详细描述（前置条件、输入、预期结果）。
  final String description;

  /// 测试类型：单元测试 / 组件测试 / 集成测试 / 端到端测试。
  final String testType;

  /// 为什么这个测试重要（风险说明）。
  final String whyImportant;

  factory RecommendedTestCase.fromJson(Map<String, dynamic> json) => RecommendedTestCase(
        module: json['module']?.toString() ?? '',
        priority: json['priority']?.toString() ?? 'medium',
        category: json['category']?.toString() ?? '边界值',
        scenario: json['scenario']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        testType: json['testType']?.toString() ?? '单元测试',
        whyImportant: json['whyImportant']?.toString() ?? '',
      );
}

/// 测试执行结果（由测试执行器运行 flutter test / dart test 解析得到）。
class TestExecutionResult {
  const TestExecutionResult({
    required this.total,
    required this.passed,
    required this.failed,
    required this.skipped,
    required this.duration,
    required this.failures,
    required this.success,
    required this.rawOutput,
  });

  final int total;
  final int passed;
  final int failed;
  final int skipped;
  final Duration duration;
  final List<TestFailure> failures;
  final bool success;
  final String rawOutput;
}

class TestFailure {
  const TestFailure({
    required this.name,
    required this.error,
    required this.stackTrace,
  });

  final String name;
  final String error;
  final String stackTrace;
}

/// 单个测试用例的执行状态（用于卡片内单独运行测试）。
enum CaseRunState { idle, running, done, error }

class CaseRunStatus {
  const CaseRunStatus({this.state = CaseRunState.idle, this.result, this.error});

  final CaseRunState state;
  final TestExecutionResult? result;
  final String? error;
}

/// 单个测试用例的代码生成状态。
enum CaseGenState { idle, generating, done, error }

class CaseGenStatus {
  const CaseGenStatus({this.state = CaseGenState.idle, this.code, this.error, this.filePath});

  final CaseGenState state;
  final String? code;
  final String? error;

  /// 生成代码已写入源项目的测试文件路径（相对项目根，如 test/foo_test.dart）。
  /// 为 null 表示未写入（如 module 推导不出文件路径）。
  final String? filePath;
}
