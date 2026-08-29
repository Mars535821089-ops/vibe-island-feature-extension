#!/bin/zsh
set -euo pipefail

LAUNCH_AGENT_LABEL="local.vibeisland.menu-spacer.autostart"

# Unload first so an intentional stop cannot race with launchd relaunching it.
launchctl bootout "gui/$(id -u)/$LAUNCH_AGENT_LABEL" 2>/dev/null || true

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

echo "占位程序和本次登录启动任务已停止；NSStatusItem 已释放。下次登录仍会按 plist 自动启动。"
