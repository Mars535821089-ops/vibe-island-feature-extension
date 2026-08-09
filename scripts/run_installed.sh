#!/bin/zsh
set -euo pipefail

APP="$HOME/Applications/Vibe Island Menu Spacer.app"
if [[ ! -d "$APP" ]]; then
  echo "未找到已安装的占位程序，请先运行 scripts/install.sh。" >&2
  exit 1
fi
if pgrep -x VibeIslandMenuSpacer >/dev/null 2>&1; then
  echo "VibeIslandMenuSpacer 已在运行。"
  exit 0
fi
open "$APP"
echo "已启动已安装的无文字占位程序。"
