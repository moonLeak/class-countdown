#!/bin/bash
# 推送到 GitHub 并打第一个 tag，触发自动构建与发布。
set -euo pipefail
cd "$(dirname "$0")"

REMOTE="https://github.com/moonLeak/class-countdown.git"

# 仓库是在一个不允许删文件的沙盒里初始化的，清掉遗留的临时对象
find .git/objects -name 'tmp_obj_*' -delete 2>/dev/null || true

git add -A
git commit -qm "feat: 菜单栏日程倒计时首个版本" || echo "(没有新变更)"

git remote get-url origin >/dev/null 2>&1 || git remote add origin "$REMOTE"

echo "==> 推送"
git push -u origin main

echo "==> 打 tag v1.0.0，触发 GitHub Actions 构建与发布"
git tag -f v1.0.0
git push -f origin v1.0.0

echo ""
echo "完成。几分钟后这里会出现可下载的 dmg："
echo "https://github.com/moonLeak/class-countdown/releases"
