# Kage —— 企业级 Claude Code 可视化 IDE

把 Claude Code 包装成给非技术/不同角色员工也能一键用的桌面 IDE。
覆盖 **后端 / 前端 / 产品 / 测试** 四个角色，每个角色看到专属的 Prompt 模板与 Skills。
跨平台：**macOS** 与 **Windows**。

## 核心特性

- **角色化入口**：切换角色即换工作台，模板与 Skill 自动按角色过滤。
- **可视化对话**：流式渲染 Claude 的思考、文本、工具调用与结果，Markdown 实时排版。
- **20 个内置 Prompt 模板**：每角色 5 个高频任务，填表即生成。
- **Skill 一键触发**：扫描 `~/.claude/skills/`，按角色映射展示，点击发 `/<name>`。
- **会话历史**：每个项目下的会话自动持久化，支持 `--resume` 续接上下文。
- **企业 API Key**：首启填入后写入 `~/.claude/settings.json`，与本机 claude 共享。
- **零运维**：纯客户端，无后端。

## 运行环境要求

| 平台      | 要求                                      |
|---------|-----------------------------------------|
| Windows | 10+，启用「开发者模式」（系统设置 → 开发者选项），Flutter 3.x |
| macOS   | 12+，Flutter 3.x，Xcode 命令行工具             |

**关键前提：本机已安装 Claude Code CLI**（`claude --version` 可用）。
安装地址：<https://claude.com/claude-code>

## 开发运行

```bash
# 安装依赖
flutter pub get

# 运行（Windows）
flutter run -d windows

# 运行（macOS）
flutter run -d macos
```

> 首次启动会进入首启向导，检测 claude 并引导填入 Anthropic API Key。

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

macOS 首次分发给其他员工时需进行代码签名 / 公证（否则需右键打开一次）：

```bash
# 在 Info.plist 中设置团队 ID 后
flutter build macos --release
codesign --deep --force --options runtime --sign "Developer ID Application: <Name>" build/macos/Build/Products/Release/Kage.app
xcrun notarytool submit build/kage-macos-<version>.dmg --keychain-profile "kage" --wait
xcrun stapler staple build/kage-macos-<version>.dmg
```

## 目录结构

```
lib/
├── app/             应用入口、路由、主题、全局 providers
├── core/
│   ├── claude/      ClaudeProcess（spawn + stream-json）、事件类型、检测器
│   ├── storage/     SettingsService + 写入 ~/.claude/settings.json
│   └── utils/       平台差异、模板渲染
├── data/
│   ├── models/      Role / Project / PromptTemplate / Skill / ChatMessage / ChatSession
│   ├── presets/     内置模板与 Skill 映射加载
│   └── repositories/ Project / Skills / Session 仓库
├── features/
│   ├── home/        主壳：角色 + 项目 + 侧栏
│   ├── onboarding/  首启向导
│   ├── projects/    项目（工作目录）管理
│   ├── chat/        对话窗（流式渲染、停止/重发）
│   ├── templates/   Prompt 模板面板 + 参数表单
│   ├── skills/      Skills 面板
│   ├── sessions/    历史会话面板
│   └── settings/    全局设置
└── shared/          （预留）复用组件

assets/presets/
├── templates/{backend,frontend,product,qa}.json   每角色 5 个模板
└── skills.json                                    Skill → 角色映射

scripts/
├── build-windows.ps1   Windows 一键打包
└── build-macos.sh      macOS 一键打包
```

## 自定义模板与 Skill 映射

**Prompt 模板**：编辑 `assets/presets/templates/<role>.json` 后重新打包。
每个模板支持 `{{param}}` 占位符；`parameters` 数组定义表单字段。

**Skill 角色映射**：编辑 `assets/presets/skills.json`：

```json
{
  "skill-name": ["backend", "frontend"]
}
```

未在映射中声明的 Skill 默认对所有角色可见。

## 数据存储

| 内容      | 位置                                                                                             |
|---------|------------------------------------------------------------------------------------------------|
| 全局设置    | `%APPDATA%\com.kage\shared_preferences.json`（Win）/ `~/Library/Preferences/com.kage.plist`（mac） |
| 项目列表    | `<app support dir>/Kage/projects.json`                                                         |
| 会话索引    | `<app support dir>/Kage/sessions/index.json`                                                   |
| 会话消息    | `<app support dir>/Kage/sessions/messages/<id>.json`                                           |
| API Key | `~/.claude/settings.json`（与本机 claude 共享）                                                       |

## 安全提示

- 企业 API Key 通过 Kage 写入本机 `~/.claude/settings.json`，分发时请通过 IT 内部文档传递，**不要把
  Key 硬编码进安装包**。
- Kage 默认权限模式 `default`，编辑类操作会让用户确认，避免误改代码。

## 后续演进

- 后端中转（统一调用审计、配额管控、SSO）
- 更丰富的代码编辑器内嵌（与 VS Code LSP 联动）
- 工作目录文件预览与差异展示
- 角色 RBAC 强限制（当前为软限制）
