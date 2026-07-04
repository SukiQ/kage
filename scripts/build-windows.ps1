# Kage Windows 打包脚本
# 用法：powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
[CmdletBinding()]
param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/.."
Set-Location $root

Write-Host "==> flutter clean" -ForegroundColor Cyan
flutter clean

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

Write-Host "==> flutter build windows --release" -ForegroundColor Cyan
flutter build windows --release

$staging = "$root\build\kage-windows-$Version"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging | Out-Null

Copy-Item -Recurse "$root\build\windows\x64\runner\Release\*" $staging

$zip = "$root\build\kage-windows-$Version.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$staging\*" -DestinationPath $zip

Write-Host "==> 打包完成：$zip" -ForegroundColor Green
Write-Host "    解压目录：$staging"
