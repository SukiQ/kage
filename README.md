# Kage —— 企业级代码质量治理 IDE

面向工程团队的桌面 IDE，对项目做**扫描 → 分析 → 修复 → 验证**的全流程质量治理，覆盖代码质量、安全审查、架构分析、性能分析、质量测试五大维度。跨平台：**macOS** 与 **Windows**。

> 关键前提：本机已安装 Claude Code CLI（`claude --version` 可用）。AI 分析与修复能力由 Claude Code 提供，安装见 <https://claude.com/claude-code>

---

## 核心特性

- **五大治理维度**：总览、代码质量、安全审查、架构分析、性能分析、质量测试，各有独立工作台。
- **SonarQube 量化扫描**：一键扫描产出 Bugs、漏洞、安全热点、技术债、覆盖率与质量门禁等指标。
- **AI 分析与修复**：代码质量问题支持单条 / 一键批量修复，安全审查给出处置建议，架构与性能由 AI 生成可视化报告。
- **测试规划与生成**：AI 推荐缺失测试用例，生成测试代码并写入项目，可一键运行验证。
- **Issue 生命周期**：修复 / 忽略 / 重新计入，按项目持久化，并按规则记忆修复附言。
- **多语言支持**：支持多种开发语言。

## 五大维度

| 维度 | 能做什么 |
|------|---------|
| **总览** | SonarQube 扫描 + 质量门禁状态 + 五维度评分卡片 |
| **代码质量** | 问题清单、严重度分布，单条 / 一键批量 AI 修复 |
| **安全审查** | 漏洞与安全热点列表，AI 给出分析与处置 |
| **架构分析** | AI 阅读项目代码，生成模块依赖架构图与开发提示 |
| **性能分析** | AI 识别性能瓶颈与优化机会，产出性能报告 |
| **质量测试** | AI 规划缺失用例 → 生成测试代码写入项目 → 运行测试 |

## 多语言支持

| 语言 / 技术栈 | 支持 |
|---------------|:----:|
| Java | ✓ |
| Kotlin | ✓ |
| Python | ✓ |
| Go | ✓ |
| C# / .NET | ✓ |
| JavaScript | ✓ |
| TypeScript | ✓ |
| HTML / CSS | ✓ |
| Vue | ✓ |
| React | ✓ |
| Angular | ✓ |
| Flutter / Dart | ✓ |
| React Native | ✓ |
| Swift | ✓ |

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

**方式一：Zip 分发（快速）**

```bash
flutter build macos --release
zip -r Kage-macos-1.0.0.zip build/macos/Build/Products/Release/Kage.app
```

下载后解压运行 `Kage.app`。首次运行可能需要右键"打开"绕过 Gatekeeper。

**方式二：Dmg + 签名（生产）**

```bash
bash scripts/build-macos.sh
# 产物：build/kage-macos-<version>.dmg
```

分发给其他员工时需代码签名 / 公证：

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
│   ├── overview/    总览仪表板
│   ├── code_quality/  代码质量（问题清单 + AI 修复）
│   ├── security_review/ 安全审查
│   ├── arch_analysis/  架构分析
│   ├── perf_analysis/  性能分析
│   ├── quality_test/   质量测试（规划 + 生成 + 执行）
│   ├── projects/ / settings/ / onboarding/
└── shared/          widgets / theme
```

## 工作原理

AI 能力通过调用本机 Claude Code CLI 完成（以 bypass 权限运行，可直接读写项目文件、执行构建与测试命令），基于 `stream-json` 协议实时回传思考、工具调用与结果，由 Kage 解析后做编排与可视化呈现。SonarQube 扫描数据会作为上下文注入，使分析基于真实指标。

## 安全提示

- AI 以 bypass 权限运行，会直接修改项目源码并执行命令，请在受信任的项目目录上使用。
- 企业 API Key 通过 Kage 写入本机 `~/.claude/settings.json`，分发时走 IT 内部文档，**切勿硬编码进安装包**。

## 后续演进

- 后端中转：统一调用审计、配额管控、SSO
- 工作目录文件预览与差异展示
- 更细粒度的项目级权限策略
