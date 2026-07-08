import '../../data/models/issue_record.dart';
import '../scanners/scan_result.dart';
import 'analysis_dimension.dart';
import 'test_plan_report.dart';

/// 为每个分析维度生成 Claude 的系统提示和初始上下文消息。
class AnalysisPrompt {
  const AnalysisPrompt._();

  /// 根据维度和扫描结果构建发给 Claude 的初始消息。
  static String buildInitialMessage({
    required AnalysisDimension dimension,
    required String projectName,
    required String projectPath,
    ScanResult? scanResult,
  }) {
    final context = _buildScanContext(scanResult, dimension);
    return switch (dimension) {
      AnalysisDimension.codeQuality => '''
你是一位资深代码质量工程师，正在对项目「$projectName」进行代码质量深度分析。
项目路径：$projectPath

$context

请对代码质量进行全面分析，重点关注：
1. Bug 风险点及修复优先级
2. 代码异味的根本原因和重构建议
3. 重复代码的合并策略
4. 技术债的系统性偿还计划

请给出可操作的、具体的改进建议。''',

      AnalysisDimension.securityReview => '''
你是一位资深应用安全专家，正在对项目「$projectName」进行安全审查。
项目路径：$projectPath

$context

请对安全风险进行深度分析，重点关注：
1. 高危漏洞（OWASP Top 10、SQL 注入、XSS、CSRF 等）
2. 安全热点的实际风险评估
3. 敏感数据处理和密钥管理问题
4. 认证授权逻辑缺陷

请给出安全加固的优先级排序和具体修复方案。''',

      AnalysisDimension.archAnalysis => '''
你是一位资深软件架构师，正在对项目「$projectName」进行架构分析。
项目路径：$projectPath

$context

请对软件架构进行深度分析，重点关注：
1. 项目主要模块和分层职责是否清晰
2. 模块边界与依赖方向是否合理
3. 是否存在越层调用、循环依赖或过度耦合
4. 哪些模块应作为 AI 辅助开发时的重点上下文

请给出架构地图、模块联系解读和后续开发建议。''',

      AnalysisDimension.perfAnalysis => '''
你是一位资深性能优化专家，正在对项目「$projectName」进行性能分析。
项目路径：$projectPath

$context

请对性能问题进行深度分析，重点关注：
1. 算法复杂度问题（O(n²) 以上的热路径）
2. 数据库查询性能（N+1、全表扫描）
3. 内存分配和 GC 压力
4. 并发和锁竞争问题

请给出性能优化的优先级和具体方案。''',

      AnalysisDimension.qualityTest => '''
你是一位资深质量保障工程师，正在对项目「$projectName」进行测试质量分析。
项目路径：$projectPath

$context

请对测试质量进行深度分析，重点关注：
1. 测试覆盖率不足的高风险模块
2. 测试用例质量（边界值、异常路径）
3. 测试隔离性和可靠性问题（Flaky Tests）
4. 缺失的集成测试和端到端测试

请给出测试补全的优先级和最佳实践建议。''',
    };
  }

  /// 单个问题的修复指令：让 AI 直接修改项目代码文件修复该问题。
  /// [dimension] 为 securityReview 时切换为安全加固措辞，默认代码质量。
  static String buildFixSingleMessage(
    IssueRecord issue,
    String? note, {
    AnalysisDimension dimension = AnalysisDimension.codeQuality,
  }) {
    final isSecurity = dimension == AnalysisDimension.securityReview;
    final buf = StringBuffer(isSecurity
        ? '请直接修改项目代码文件，修复以下安全问题（漏洞/安全热点），完成安全加固：\n\n'
        : '请直接修改项目代码文件，修复以下 SonarQube 问题：\n\n');
    buf.writeln('- 文件：${issue.component}:${issue.line ?? '-'}');
    buf.writeln('- 规则（rule）：${issue.rule}');
    buf.writeln('- 问题描述：${issue.message}');
    if (note != null && note.trim().isNotEmpty) {
      buf.writeln('- 修复附言（用户指定的修复方式/偏好）：${note.trim()}');
    }
    buf.write(isSecurity
        ? '\n要求：\n1. 定位到对应文件与代码行，按安全编码规范修复（输入校验、参数化查询、最小权限、敏感信息脱敏等），彻底消除该漏洞\n2. 保持修复最小化，不引入新的安全问题或回归\n3. 修复完成后简要说明改动内容及为何安全'
        : '\n要求：\n1. 定位到对应文件与代码行，直接修改源码完成修复\n2. 保持修复最小化，不引入新问题\n3. 修复完成后简要说明你改动了什么');
    return buf.toString();
  }

  /// 批量修复指令：让 AI 逐一修复多个问题。
  /// [dimension] 为 securityReview 时切换为安全加固措辞，默认代码质量。
  static String buildFixAllMessage(
    List<IssueRecord> issues,
    Map<String, String> notes, {
    AnalysisDimension dimension = AnalysisDimension.codeQuality,
  }) {
    final isSecurity = dimension == AnalysisDimension.securityReview;
    final buf = StringBuffer(isSecurity
        ? '请直接修改项目代码文件，逐一修复以下 ${issues.length} 个安全问题（漏洞/安全热点），完成安全加固：\n\n'
        : '请直接修改项目代码文件，逐一修复以下 ${issues.length} 个 SonarQube 问题：\n\n');
    for (var i = 0; i < issues.length; i++) {
      final it = issues[i];
      buf.writeln('${i + 1}. [${it.component}:${it.line ?? '-'}] '
          '${it.rule} - ${it.message}');
      final note = notes[it.rule];
      if (note != null && note.isNotEmpty) {
        buf.writeln('   附言：$note');
      }
    }
    buf.write(isSecurity
        ? '\n要求：\n1. 逐条定位并修改源码，按安全编码规范彻底修复每个安全问题\n2. 相同 rule 的问题用一致的安全修复方式\n3. 完成后按列表简要说明每条的改动及为何安全'
        : '\n要求：\n1. 逐条定位并修改源码，每个问题都要实际修复\n2. 相同 rule 的问题尽量用一致的方式修复\n3. 完成后按列表简要说明每条的改动''');
    return buf.toString();
  }

  /// 架构图分析指令：让 AI 阅读项目代码，输出严格 JSON 架构图。
  static String buildArchitectureGraphMessage({
    required String projectName,
    required String projectPath,
  }) {
    return '''
你是一位资深软件架构师。请分析项目「$projectName」（路径：$projectPath）的实际代码，识别项目的分层、模块职责与模块间的调用/依赖关系，输出可视化的架构图数据。

要求：
1. 使用 Read / Glob / Grep 工具阅读项目源码（优先 lib 目录），识别真实的架构分层与模块。**禁止使用 Bash 或任何写入/执行类工具**，只做只读分析。
2. 高效分析：先 Glob 浏览目录结构，再有针对性地 Read 各模块的代表文件（入口、核心类），不要逐个读取所有文件。
3. 节点数量控制在 5~12 个，边数量控制在 6~20 条，避免图过载。
4. 仅输出一个 JSON 对象，不要 Markdown、不要解释、不要 Mermaid。
5. JSON 必须严格合法：字符串值内部**不得出现未转义的双引号**；引用代码字面量/常量值时请改用中文引号「」（如 硬编码为「0/10 * * * * ?」），切勿直接写入半角双引号，否则会破坏 JSON 结构。

JSON 结构：
{
  "summary": "对项目架构的一句话总结",
  "nodes": [
    {"id": "app", "label": "应用入口", "layer": "应用入口", "description": "路由、主题、全局装配"}
  ],
  "edges": [
    {"from": "features", "to": "core", "label": "调用核心能力"}
  ],
  "developmentHints": ["AI 辅助开发此项目时的注意事项1", "注意事项2"]
}

字段说明：
- id：节点唯一标识（英文短词，如 app/features/core/data/shared）
- label：节点显示名称（中文）
- layer：从固定集合选取：「应用入口」「业务功能」「核心能力」「数据层」「共享组件」「外部系统」
- description：该模块/层职责（一句话）
- edges.from / edges.to：引用 nodes 的 id
- edges.label：依赖关系简述
- developmentHints：AI 辅助开发此项目时的注意事项

现在请直接输出 JSON。''';
  }

  /// 性能分析指令：让 AI 阅读项目代码，输出严格 JSON 性能报告。
  static String buildPerformanceReportMessage({
    required String projectName,
    required String projectPath,
  }) {
    return '''
你是一位资深性能优化专家。请分析项目「$projectName」（路径：$projectPath）的实际代码，识别潜在的性能问题与优化机会，输出结构化的性能分析报告。

要求：
1. 使用 Read / Glob / Grep 工具阅读项目源码，重点关注循环密集、数据库访问、大对象分配、锁与同步、I/O 与序列化相关代码。**禁止使用 Bash 或任何写入/执行类工具**，只做只读分析。
2. 高效分析：先 Glob 浏览目录结构，再有针对性地 Read 热点文件，不要逐个读取所有文件。
3. 聚焦真实、可定位的性能问题，每条都给出具体文件/行号与可操作的优化方案；避免泛泛而谈或无依据的猜测。
4. 问题数量控制在 5~15 条；若代码中确实没有明显性能问题，issues 留空并在 summary 中说明。
5. 仅输出一个 JSON 对象，不要 Markdown、不要解释、不要代码块标记。
6. JSON 必须严格合法：字符串值内部**不得出现未转义的双引号**；引用代码字面量/常量值（如 cron 表达式、SQL 片段、字符串常量）时请改用中文引号「」，切勿直接写入半角双引号，否则会破坏 JSON 结构。

JSON 结构：
{
  "summary": "整体性能评估一句话",
  "overall": "critical",
  "issues": [
    {
      "category": "算法复杂度",
      "severity": "high",
      "file": "lib/xxx.dart",
      "line": 42,
      "title": "问题标题",
      "description": "问题描述（为什么是性能瓶颈）",
      "suggestion": "具体优化方案",
      "impact": "high"
    }
  ],
  "suggestions": ["系统性优化建议1", "建议2"]
}

字段说明：
- overall 取值：critical / high / medium / low / good（整体性能健康度）
- category 从固定集合选取：「算法复杂度」「数据库性能」「内存与GC」「并发与锁」「I/O瓶颈」「资源使用」
- severity 取值：critical / high / medium / low（问题严重度）
- impact 取值：high / medium / low（修复后的收益）
- file / line 指向真实代码位置；line 为整数或省略

现在请直接输出 JSON。''';
  }

  /// 测试计划分析指令：让 AI 阅读项目代码和现有测试，输出严格 JSON 测试计划。
  static String buildTestPlanMessage({
    required String projectName,
    required String projectPath,
  }) {
    return '''
你是一位资深质量保障工程师。请分析项目「$projectName」（路径：$projectPath）的源代码和现有测试，识别测试缺口并推荐高质量的测试用例。

要求：
1. 使用 Read / Glob / Grep 工具阅读源码（优先 lib/ 目录）和现有测试（test/ 目录）。**禁止使用 Bash 或任何写入/执行类工具**，只做只读分析。
2. 高效分析：先 Glob 浏览 lib/ 与 test/ 目录结构，识别测试覆盖情况；再 Read 关键业务逻辑、边界处理、异常分支、状态转换相关代码。
3. 聚焦真实、可定位的测试场景：每条推荐都对应具体模块与代码逻辑，给出可操作的测试描述（前置条件/输入/预期结果）；避免泛泛而谈。
4. 推荐数量控制在 8~20 条；若代码已有充分测试，recommendedCases 留空并在 summary 中说明。
5. 仅输出一个 JSON 对象，不要 Markdown、不要解释、不要代码块标记。
6. JSON 必须严格合法：字符串值内部**不得出现未转义的双引号**；引用代码/常量时改用中文引号「」，切勿直接写入半角双引号。

JSON 结构：
{
  "summary": "整体测试质量评估一句话",
  "coverageGaps": {
    "overallCoverage": 0.65,
    "highRiskModules": ["lib/features/auth/", "lib/core/payment/"]
  },
  "recommendedCases": [
    {
      "module": "lib/features/auth/login_form.dart",
      "priority": "high",
      "category": "异常流程",
      "scenario": "登录失败时错误信息不泄露敏感数据",
      "description": "模拟密码错误、账号锁定等场景，验证错误信息只显示「用户名或密码错误」，不泄露用户名是否存在。",
      "testType": "单元测试",
      "whyImportant": "防止用户枚举攻击，属于安全相关的高风险路径。"
    }
  ],
  "suggestions": ["系统性建议1", "建议2"]
}

字段说明：
- overallCoverage 取值 0~1（基于 test/ 目录覆盖情况的估算，非精确度量）
- priority 取值：critical / high / medium / low
- category 从固定集合选取：「边界值」「异常流程」「状态转换」「并发场景」「性能压力」「安全漏洞」
- testType 从固定集合选取：「单元测试」「组件测试」「集成测试」「端到端测试」
- module / scenario / description / whyImportant 均为中文

现在请直接输出 JSON。''';
  }

  /// 测试结果解读指令：让 AI 解读测试执行结果（失败原因、Flaky 分析、改进建议）。
  static String buildTestResultInterpretMessage(TestExecutionResult result) {
    final buf = StringBuffer('''
你是一位资深质量保障工程师，请解读以下测试执行结果，给出专业分析与改进建议。

【测试结果概览】
- 测试总数：${result.total}
- 成功：${result.passed}
- 失败：${result.failed}
- 跳过：${result.skipped}
- 耗时：${result.duration.inSeconds} 秒
''');
    if (result.failures.isNotEmpty) {
      buf.writeln('\n【失败用例详情（共 ${result.failures.length} 条）】');
      for (var i = 0; i < result.failures.length; i++) {
        final f = result.failures[i];
        buf.writeln('\n${i + 1}. ${f.name}');
        if (f.error.isNotEmpty) buf.writeln('   错误：${f.error}');
        if (f.stackTrace.isNotEmpty) {
          final trace = f.stackTrace.length > 600
              ? '${f.stackTrace.substring(0, 600)}…'
              : f.stackTrace;
          buf.writeln('   堆栈：$trace');
        }
      }
    }
    buf.write('''

请分析：
1. 失败测试的根本原因分类（断言错误、空指针、异步超时、依赖缺失、环境问题等）
2. 是否存在 Flaky Tests（不稳定/时好时坏的测试）及判断依据
3. 整体测试质量评估（成功率、覆盖面、可靠性）
4. 按优先级给出修复建议和测试改进方向

如需查看具体测试代码，可使用 Read / Glob / Grep 工具（只读）。仅输出文本分析，不要修改任何文件。''');
    return buf.toString();
  }

  /// 测试代码生成指令：让 AI 阅读源码、按项目语言/惯例用 Write 直接写入测试文件，
  /// 并在回复正文粘贴完整代码（语言无关，Java/Python/Dart 等通用）。
  static String buildTestCodeMessage({
    required String projectName,
    required RecommendedTestCase testCase,
  }) {
    final module = testCase.module.isEmpty ? '（未指定，请按场景推断被测目标）' : testCase.module;
    return '''
你是一位资深软件测试工程师。请为项目「$projectName」的以下测试用例生成可运行的测试代码，并直接写入项目。

【测试用例】
- 模块：$module
- 场景：${testCase.scenario}
- 类别：${testCase.category}
- 测试类型：${testCase.testType}
- 描述：${testCase.description.isEmpty ? '（无）' : testCase.description}
- 重要性：${testCase.whyImportant.isEmpty ? '（无）' : testCase.whyImportant}

要求：
1. 先用 Read / Glob / Grep 阅读被测模块（$module）的真实源码，以及项目现有的测试目录，弄清：实际的类名、方法签名、构造参数、依赖与导出；该项目使用的语言、测试框架与测试目录约定（例如 Java/Maven→`src/test/java/**/*Test.java`，Python→`tests/test_*.py`，Dart/Flutter→`test/*_test.dart`，按项目实际情况为准）。
2. 按该语言与测试框架的惯例编写测试，充分覆盖该场景：包含正常路径，以及与「${testCase.category}」相关的边界/异常断言；测试名要具描述性。外部依赖用 mock/fake 隔离，保证稳定可重复。
3. 用 Write 工具把测试代码**直接写入项目的正确测试路径**，文件名遵循该语言惯例（如 `XxxTest.java` / `test_xxx.py` / `xxx_test.dart`）；若已存在同类测试文件，在其基础上补充而非覆盖既有用例。
4. 写入完成后，在回复正文里**粘贴完整的测试代码**（从 import / 包声明开始），并用一句话说明写入了哪个文件、覆盖了哪些场景。

现在请开始：阅读源码 → 写入测试文件 → 在回复中粘贴代码并说明。''';
  }

  /// 测试运行指令：委托 AI 识别构建工具并运行指定测试目标，末尾以约定 JSON 汇总结果。
  static String buildTestRunMessage({
    required String projectName,
    required String testTarget,
  }) {
    final target = testTarget.isEmpty ? '项目的全部测试' : testTarget;
    return '''
你是测试运行助手。请在项目「$projectName」中运行测试：$target。

要求：
1. 识别项目的构建/测试工具并用合适命令运行上述测试目标：Maven→`mvn test`（限定单类加 `-Dtest=类名`）、Gradle→`./gradlew test`（`--tests 类名`）、Flutter→`flutter test`、Dart→`dart test`、Python→`pytest` 等。已指定文件路径时，定位到对应的测试类/文件再运行。
2. 读懂执行结果（编译错误、通过/失败用例、失败堆栈），可在过程中用 Bash 执行命令。
3. 回复正文简要说明运行情况（用了什么命令、总体结论），并在**最后一行**严格输出一行 JSON 汇总（不要 Markdown 代码围栏）：
{"passed": <int>, "failed": <int>, "skipped": <int>, "success": <true|false>, "failures": [{"name": "<用例名>", "error": "<失败原因，压缩为单行>"}]}

现在请运行测试并输出结果。''';
  }

  static String _buildScanContext(ScanResult? result, AnalysisDimension dim) {
    if (result == null) return '（尚未执行 SonarQube 扫描，请基于项目代码进行分析）';

    final buf = StringBuffer('【SonarQube 扫描数据】\n');
    final m = result.metrics;

    switch (dim) {
      case AnalysisDimension.codeQuality:
        if (m.bugs != null) buf.writeln('- Bugs: ${m.bugs}');
        if (m.codeSmells != null) buf.writeln('- 代码异味: ${m.codeSmells}');
        if (m.duplicatedLinesDensity != null) buf.writeln('- 重复行率: ${m.duplicatedLinesDensity!.toStringAsFixed(1)}%');
        if (m.technicalDebtMinutes != null) buf.writeln('- 技术债: ${m.technicalDebtMinutes}min');
        if (m.reliabilityRating != null) buf.writeln('- 可靠性评级: ${m.reliabilityRating}');
      case AnalysisDimension.securityReview:
        if (m.vulnerabilities != null) buf.writeln('- 漏洞数: ${m.vulnerabilities}');
        if (m.securityHotspots != null) buf.writeln('- 安全热点: ${m.securityHotspots}');
        if (m.securityRating != null) buf.writeln('- 安全评级: ${m.securityRating}');
      case AnalysisDimension.qualityTest:
        if (m.coverage != null) buf.writeln('- 测试覆盖率: ${m.coverage!.toStringAsFixed(1)}%');
      default:
        buf.writeln('- 总问题数: ${result.totalIssues ?? result.issues.length}');
        buf.writeln('- 质量门禁: ${result.qualityGateStatus ?? '未知'}');
    }

    // 严重问题摘要（仅 BLOCKER/CRITICAL）
    final critical = result.issues
        .where((i) => i.severity == ScanSeverity.blocker || i.severity == ScanSeverity.critical)
        .take(10)
        .toList();
    if (critical.isNotEmpty) {
      buf.writeln('\n【高危问题（前 ${critical.length} 条）】');
      for (final i in critical) {
        buf.writeln('- [${i.severity.label}] ${i.message}  (${i.component}:${i.line ?? '-'})');
      }
    }

    return buf.toString();
  }
}
