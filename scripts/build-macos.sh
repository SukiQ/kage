#!/usr/bin/env bash
# Kage macOS 打包脚本
# 用法：bash scripts/build-macos.sh [version]
set -euo pipefail

VERSION="${1:-1.0.0}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> flutter clean"
flutter clean

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build macos --release"
flutter build macos --release

APP="$ROOT/build/macos/Build/Products/Release/Kage.app"
if [[ ! -d "$APP" ]]; then
  echo "未找到产物：$APP" >&2
  exit 1
fi

DMG_DIR="$ROOT/build/macos-dmg"
DMG="$ROOT/build/kage-macos-$VERSION.dmg"
mkdir -p "$DMG_DIR"
rm -rf "$DMG_DIR/Kage.app" "$DMG"
cp -R "$APP" "$DMG_DIR/"

# 若安装了 create-dmg 则生成更精致的 dmg，否则用 hdiutil 兜底
if command -v create-dmg >/dev/null 2>&1; then
  create-dmg --volname "Kage $VERSION" --window-pos 200 120 --window-size 600 400 \
    --icon-size 100 --app-drop-link 425 200 "$DMG" "$DMG_DIR"
else
  hdiutil create -volname "Kage $VERSION" -srcfolder "$DMG_DIR" -ov -format UDZO "$DMG"
fi

echo "==> 打包完成：$DMG"
