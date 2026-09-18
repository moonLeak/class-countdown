#!/bin/bash
# 一条命令产出可运行的 ClassCountdown.app。
# 只需要 Xcode Command Line Tools，不需要打开 Xcode。
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="ClassCountdown"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
TARGET="$(uname -m)-apple-macos14.0"

echo "==> 清理"
rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "==> 编译 ($TARGET)"
swiftc \
  -parse-as-library \
  -O \
  -target "$TARGET" \
  -framework SwiftUI \
  -framework AppKit \
  -framework EventKit \
  -framework ServiceManagement \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  Sources/*.swift

echo "==> 组装 bundle"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> 临时签名 (ad-hoc)"
# 日历权限需要稳定的签名标识，否则每次重建都会重新弹权限窗。
codesign --force --sign - --identifier com.carson.classcountdown "$APP"

echo ""
echo "完成: $APP"
echo "运行:  open \"$APP\""
echo "安装:  cp -R \"$APP\" /Applications/"
