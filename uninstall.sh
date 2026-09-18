#!/bin/bash
# 彻底卸载 ClassCountdown：退出进程、删应用、清偏好设置与登录项。
set -uo pipefail

APP_NAME="ClassCountdown"
BUNDLE_ID="com.carson.classcountdown"

echo "==> 退出正在运行的实例"
pkill -x "$APP_NAME" 2>/dev/null && echo "   已退出" || echo "   没有在运行"
sleep 1

echo "==> 注销开机自启"
# 应用已经不在了的话这条会静默失败，无所谓
/bin/launchctl bootout "gui/$(id -u)/$BUNDLE_ID" 2>/dev/null || true

echo "==> 删除应用"
for p in "/Applications/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app"; do
  if [ -d "$p" ]; then
    rm -rf "$p" && echo "   删除 $p"
  fi
done

echo "==> 清理偏好设置"
defaults delete "$BUNDLE_ID" 2>/dev/null && echo "   已清理" || echo "   没有残留"
rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist"
rm -rf "$HOME/Library/Caches/$BUNDLE_ID"
rm -rf "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"

echo "==> 清理本地构建产物"
cd "$(dirname "$0")"
rm -rf build dist && echo "   已清理"

echo ""
echo "卸载完成。"
echo ""
echo "日历权限记录还留在系统里，想一并清掉的话："
echo "  系统设置 → 隐私与安全性 → 日历，把 $APP_NAME 那一项删掉"
