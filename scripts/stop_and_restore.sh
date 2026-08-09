#!/bin/zsh
set -euo pipefail

if pgrep -x VibeIslandMenuSpacer >/dev/null 2>&1; then
  pkill -TERM -x VibeIslandMenuSpacer
  for _ in {1..20}; do
    pgrep -x VibeIslandMenuSpacer >/dev/null 2>&1 || break
    sleep 0.1
  done
fi

if pgrep -x VibeIslandMenuSpacer >/dev/null 2>&1; then
  pkill -KILL -x VibeIslandMenuSpacer
fi

echo "占位程序已退出；NSStatusItem 已释放，菜单栏恢复为启动前状态。"
