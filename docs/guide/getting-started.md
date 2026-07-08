# 快速开始

## 运行环境要求

| 平台 | 要求 |
|---------|-----------------------------------------|
| Windows | 10+，启用「开发者模式」（系统设置 → 开发者选项） |
| macOS | 12+，Xcode 命令行工具 |

## 关键前提：Claude Code CLI

Kage 的 AI 能力依赖本机 Claude Code。请先确认：

```bash
claude --version
```

若未安装，前往 <https://claude.com/claude-code> 安装。

## 首次启动

1. 解压 / 安装并打开 Kage。
2. 首启向导会自动检测本机 Claude Code CLI。
3. 填入 Anthropic API Key（写入 `~/.claude/settings.json`，与本机 claude 共享）。
4. 添加一个项目（工作目录），即可开始扫描与分析。

::: tip API Key
企业用户请通过 IT 内部文档获取 API Key，切勿硬编码进安装包。
:::
