# 下载

## Windows

- **版本**：1.0.0
- **大小**：约 36 MB（zip）
- **系统要求**：Windows 10+，启用「开发者模式」

👉 [下载 Windows 版（zip）](https://github.com/SukiQ/kage/releases/latest/download/kage-windows-1.0.0.zip) ｜ [查看所有版本](https://github.com/SukiQ/kage/releases)

> 解压后直接运行 `kage.exe`，免安装。首次启动会进入首启向导，检测 Claude Code CLI 并引导填入 Anthropic API Key。

## macOS

- **版本**：1.0.0
- **大小**：约 47 MB（dmg）
- **系统要求**：macOS 12+

👉 [下载 macOS 版（dmg）](https://github.com/SukiQ/kage/releases/latest/download/kage-macos-1.0.0.dmg) ｜ [查看所有版本](https://github.com/SukiQ/kage/releases)

> 安装包未签名公证。双击挂载 dmg，将 `Kage.app` 拖到「应用程序」即可。若打开时闪退，是 macOS Gatekeeper 拦截，在「终端」执行以下命令移除隔离属性后即可正常启动：
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/Kage.app
> ```
>
> 若此前多次尝试打开被拦截，系统会缓存拒绝记录导致仍闪退，需重置 LaunchServices 后重试：
>
> ```bash
> /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -seed -lint -r -all local,user,system
> ```
>
> 首启向导会检测 Claude Code CLI 并引导填入 Anthropic API Key。

::: info 关于下载链接
下载来自 GitHub Releases。若上方链接无法下载，请先到 [Releases](https://github.com/SukiQ/kage/releases) 页确认已发布对应版本（tag `v1.0.0`）并上传了 `kage-windows-1.0.0.zip` / `kage-macos-1.0.0.dmg`。
:::
