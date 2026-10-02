#!/bin/bash
# 开发用：编译、用模拟日程启动，不触发日历权限弹窗。
# 用法：./dev.sh [模拟文件路径]，默认 DevData/mock-events.json
set -euo pipefail
cd "$(dirname "$0")"

SRC="${1:-$PWD/DevData/mock-events.json}"
# 文档文件夹受系统保护，App 去读会弹“访问文稿文件夹”的权限窗并卡住启动，
# 所以复制到不受保护的位置再让 App 读
MOCK="/private/tmp/timetool-mock-events.json"
cp "$SRC" "$MOCK"
pkill -x TimeTool 2>/dev/null || true
sleep 1
./build.sh
open build/TimeTool.app --args --mock-events "$MOCK"
echo "已用模拟日程启动: $MOCK"
