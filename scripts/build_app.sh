#!/usr/bin/env bash
# ==============================================================
#  build_app.sh —— 从源码一键构建 “LaTeX 转换.app”
#
#  产物:  dist/LaTeX 转换.app
#
#  依赖:  macOS 自带 osacompile / PlistBuddy；
#         若要重新生成图标还需 python3 + pillow + iconutil
# ==============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="LaTeX 转换"
APP="$ROOT/dist/$APP_NAME.app"
ICNS="$ROOT/icon/AppIcon.icns"
PB=/usr/libexec/PlistBuddy

echo "==> 清理旧产物"
rm -rf "$ROOT/dist"
mkdir -p "$ROOT/dist"

echo "==> 编译 AppleScript → applet"
# main.applescript 里有 on open 处理程序，osacompile 会自动生成 droplet
osacompile -o "$APP" "$ROOT/src/main.applescript"

echo "==> 放入转换引擎 convert.sh"
cp "$ROOT/src/convert.sh" "$APP/Contents/Resources/convert.sh"
chmod +x "$APP/Contents/Resources/convert.sh"

echo "==> 设置图标"
if [ -f "$ICNS" ]; then
  cp "$ICNS" "$APP/Contents/Resources/applet.icns"
else
  echo "    （未找到 $ICNS，跳过；可先运行 scripts/make_icon.py 生成）"
fi

echo "==> 写入 Info.plist 元信息"
$PB -c "Set :CFBundleName $APP_NAME"            "$APP/Contents/Info.plist" 2>/dev/null \
  || $PB -c "Add :CFBundleName string $APP_NAME" "$APP/Contents/Info.plist"
$PB -c "Set :CFBundleDisplayName $APP_NAME"            "$APP/Contents/Info.plist" 2>/dev/null \
  || $PB -c "Add :CFBundleDisplayName string $APP_NAME" "$APP/Contents/Info.plist"
$PB -c "Set :LSMinimumSystemVersion 10.13"            "$APP/Contents/Info.plist" 2>/dev/null \
  || $PB -c "Add :LSMinimumSystemVersion string 10.13"  "$APP/Contents/Info.plist"

echo "==> 临时签名（避免 Gatekeeper 直接拦截）"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "    （codesign 跳过）"

echo
echo "✅ 构建完成: $APP"
