# Kage —— Agent 驱动的企业级代码质量治理 IDE

把 **Claude Code** 包装成桌面 IDE，以 Agent 为执行核心，对项目做**扫描 → 分析 → 修复 → 验证**的全自动质量治理。
覆盖代码质量、安全审查、架构分析、性能分析、质量测试五大维度，面向后端 / 前端 / 测试等工程角色。
跨平台：**macOS** 与 **Windows**。

> 关键前提：本机已安装 Claude Code CLI（`claude --version` 可用）。安装见 <https://claude.com/claude-code>

---

## 为什么是 Agent 驱动

Kage 不自己实现「分析逻辑 / 修复规则 / 测试模板」。它是一个**编排层 + 可视化层**：把每个质量任务交给一个以 `bypassPermissions` 启动的 Claude Code Agent 去完成，Kage 只负责发指令、接入数据、呈现过程与结果。

### Agent 核心特性

- **Claude Code 即引擎**：架构分析、性能瓶颈识别、安全审查、测试规划、测试代码生成、测试执行、一键批量修复——每一项都是一个独立的 Agent 任务。Agent 自主 Read 源码、Write 修改、Bash 执行，Kage 不替它做决定。

- **全自动闭环（无需逐次授权）**：所有 Agent 调用均以 `--dangerously-skip-permissions` 启动，Agent 直接读写项目源码、运行 `mvn test` / `flutter test` / `pytest` / `sonar-scanner` 等命令。一键触发后从分析到落地全程自动，**不会再卡在「请授予权限」**。

- **过程实时可见**：基于 `stream-json` 协议，Kage 实时渲染 Agent 的思考、每一次工具调用（Read / Write / Bash 等）与返回结果。Agent 在做什么、改了哪个文件、跑了什么命令，一目了然。

- **语言与技术栈无关**：Agent 自主识别项目构建工具与目录惯例（Java/Maven → `src/test/java/**/*Test.java`、Python → `tests/test_*.py`、Dart/Flutter → `test/*_test.dart` …），自行决定文件落点与运行命令。Kage **不硬编码任何语言规则**，Java / Python / Dart / Go 等开箱即用。

- **数据增强 Agent**：SonarQube 扫描产出的量化指标（Bugs、漏洞、安全热点、技术债、覆盖率、质量门禁）被注入 Agent 上下文。Agent 基于真实扫描数据分析与修复，而非凭空臆测。

- **可复用的 Agent 任务流**：每个维度是可独立触发、可复用的 Agent 任务，由 Kage 按维度调度组合（如「扫描 → 代码质量 → 一键修复 → 重扫」）。

---

## 五大治理维度

| 维台 | Agent 做什么 | Kage 呈现 |
|------|------------|----------|
| **总览** | （SonarQube 扫描） | 质量门禁、5 维度评分卡片 |
| **代码质量** | 单条 / 一键批量修复 Bugs 与异味 | 问题清单、严重度分布、修复过程流 |
| **安全审查** | 分析漏洞与安全热点并给出处置 | 漏洞列表、AI 分析结论 |
| **架构分析** | 阅读全项目代码，生成模块依赖架构图 | 可视化架构图 + 摘要 + 开发提示 |
| **性能分析** | 识别性能瓶颈与优化机会 | 性能报告（问题 + 建议） |
| **质量测试** | 规划缺失用例 → 生成测试代码并写入项目 → 运行测试 | 测试计划、代码预览、执行结果 |

其中「质量测试」是典型的 Agent 闭环：AI 规划用例 → 用 Write 把测试代码嵌入源项目正确路径 → 用项目构建工具运行 → 按约定格式回传通过/失败结果，全程无需手写路径或命令。

---

## 运行环境要求

| 平台 | 要求 |
|---------|-----------------------------------------|
| Windows | 10+，启用「开发者模式」（系统设置 → 开发者选项），Flutter 3.x |
| macOS | 12+，Flutter 3.x，Xcode 命令行工具 |

## 开发运行

```bash
flutter pub get

flutter run -d windows   # Windows
flutter run -d macos     # macOS
```

> 首次启动进入首启向导：检测本机 claude CLI、引导填入 Anthropic API Key（写入 `~/.claude/settings.json`，与本机 claude 共享）。

## 打包分发

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
# 产物：build/kage-windows-<version>.zip（解压后直接运行 kage.exe）
```

### macOS

```bash
bash scripts/build-macos.sh
# 产物：build/kage-macos-<version>.dmg
```

分发给其他员工时需代码签名 / 公证（否则需右键打开一次）：

```bash
flutter build macos --release
codesign --deep --force --options runtime --sign "Developer ID Application: <Name>" build/macos/Build/Products/Release/Kage.app
xcrun notarytool submit build/kage-macos-<version>.dmg --keychain-profile "kage" --wait
xcrun stapler staple build/kage-macos-<version>.dmg
```

---

## 目录结构

```
lib/
├── app/             入口、路由、主题、全局 providers
├── core/
│   ├── claude/      ClaudeProcess（spawn + stream-json）、事件类型、CLI 检测
│   ├── analysis/    各维度 AI 分析器 + 会话控制器 + Prompt 构建
│   │                （architecture / performance / test_plan / test_code / analysis_session_controller …）
│   ├── scanners/    SonarQube 扫描器（自动识别 Maven / Gradle / Flutter …）
│   ├── sonar/       SonarQube 客户端
│   ├── storage/     SettingsService（写 ~/.claude/settings.json）
│   └── utils/
├── data/
│   ├── models/      Project / AnalysisReport / IssueRecord …
│   ├── repositories/ Project / Issue / RuleNote 仓库
│   └── presets/
├── features/
│   ├── home/        主壳：项目选择 + 侧栏导航
│   ├── overview/    总览仪表板（扫描 + 5 维度评分）
│   ├── code_quality/  代码质量（问题清单 + AI 修复）
│   ├── security_review/ 安全审查（漏洞 + AI 分析）
│   ├── arch_analysis/  架构分析（AI 架构图）
│   ├── perf_analysis/  性能分析（AI 瓶颈识别）
│   ├── quality_test/   质量测试（AI 规划 + 生成 + 执行）
│   ├── projects/ / settings/ / onboarding/
└── shared/          widgets / theme
```

## 工作原理（Agent 编排）

1. Kage 以 `bypassPermissions` spawn 一个 Claude Code 子进程，工作目录指向所选项目。
2. 通过 `stream-json` 双向通信：Kage 发送 Prompt（可附带 SonarQube 扫描数据），实时接收 Agent 的思考 / 工具调用 / 结果事件。
3. Kage 解析事件流更新 UI：渲染对话、捕获 Agent 写入的文件路径、按约定格式解析测试执行结果。
4. Agent 直接操作项目文件与命令，完成后 Kage 汇总呈现。

> 想新增一种 Agent 能力，通常只需：写一个 Prompt 构建函数 + 一个复用 `ClaudeProcess` 的分析器 + 一个展示页。无需在 Kage 端实现任何业务规则。

## 安全提示

- **Agent 以 bypass 模式运行**：会直接修改项目源码并执行构建 / 测试命令，适合在受控的企业开发机上使用；请确保打开的是受信任的项目目录。
- 企业 API Key 通过 Kage 写入本机 `~/.claude/settings.json`，分发时走 IT 内部文档，**切勿硬编码进安装包**。

## 后续演进

- 后端中转：统一调用审计、配额管控、SSO
- Agent 任务编排链（多步自动流水线，如「修复 → 重扫 → 验证门禁」一键串跑）
- 工作目录文件预览与差异展示
- 更细粒度的项目级权限策略
