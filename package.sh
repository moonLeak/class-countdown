#!/bin/bash
# 把 build/TimeTool.app 打包成可拖拽安装的 .dmg
set -euo pipefail
cd "$(dirname "$0")"

APP="build/TimeTool.app"
[ -d "$APP" ] || { echo "先跑 ./build.sh"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGE="build/dmg"
OUT="dist/TimeTool-$VERSION.dmg"

rm -rf "$STAGE" dist
mkdir -p "$STAGE" dist

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "TimeTool" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$OUT"

echo ""
echo "完成: $OUT"
shasum -a 256 "$OUT"
