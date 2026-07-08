# 开发与打包

## 从源码运行

```bash
flutter pub get

flutter run -d windows   # Windows
flutter run -d macos     # macOS
```

## 打包分发

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
# 产物：build/kage-windows-1.0.0.zip
```

### macOS

```bash
bash scripts/build-macos.sh
# 产物：build/kage-macos-1.0.0.dmg
```

分发给其他员工时需代码签名 / 公证（否则需右键打开一次）：

```bash
flutter build macos --release
codesign --deep --force --options runtime --sign "Developer ID Application: <Name>" build/macos/Build/Products/Release/Kage.app
```

## 目录结构

```
lib/
├── app/             入口、路由、主题、全局 providers
├── core/
│   ├── claude/      ClaudeProcess（spawn + stream-json）
│   ├── analysis/    各维度 AI 分析器 + 会话控制器 + Prompt 构建
│   ├── scanners/    SonarQube 扫描器
│   └── sonar/ storage/ utils/
├── data/            models / repositories / presets
├── features/        home / overview / code_quality / security_review
│                    arch_analysis / perf_analysis / quality_test ...
└── shared/          widgets / theme
```

## 安全提示

- AI 以 bypass 权限运行，会直接修改项目源码并执行命令，请在受信任的项目目录上使用。
- 企业 API Key 通过 Kage 写入本机 `~/.claude/settings.json`，分发时走 IT 内部文档。
