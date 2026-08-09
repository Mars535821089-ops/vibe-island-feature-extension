#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
APP="$ROOT_DIR/.artifacts/Vibe Island Menu Spacer.app"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null
if pgrep -x VibeIslandMenuSpacer >/dev/null 2>&1; then
  echo "VibeIslandMenuSpacer 已在运行；未启动第二个实例。"
  exit 0
fi

open "$APP"
echo "已临时启动：$APP"
echo "占位会按主屏幕宽度自动固定在绝对中心，无需手动拖动。"
