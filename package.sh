#!/bin/bash
# 把 build/ClassCountdown.app 打包成可拖拽安装的 .dmg
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ClassCountdown.app"
[ -d "$APP" ] || { echo "先跑 ./build.sh"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
STAGE="build/dmg"
OUT="dist/ClassCountdown-$VERSION.dmg"

rm -rf "$STAGE" dist
mkdir -p "$STAGE" dist

cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "ClassCountdown" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$OUT"

echo ""
echo "完成: $OUT"
shasum -a 256 "$OUT"
