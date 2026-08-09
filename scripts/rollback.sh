#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
DEST="$HOME/Applications/Vibe Island Menu Spacer.app"

"$ROOT_DIR/scripts/stop_and_restore.sh" >/dev/null
if [[ -e "$DEST" ]]; then
  rm -rf "$DEST"
  echo "已移除占位程序：$DEST"
fi

restore_backup=""
if [[ -f "$ROOT_DIR/.restore-backup-path" ]]; then
  restore_backup="$(cat "$ROOT_DIR/.restore-backup-path")"
fi
if [[ -n "$restore_backup" && -d "$restore_backup" ]]; then
  mkdir -p "$HOME/Applications"
  mv "$restore_backup" "$DEST"
  echo "已恢复安装前备份：$DEST"
fi
defaults delete local.vibeisland.menu-spacer 2>/dev/null || true
rm -f "$ROOT_DIR/.installed-path" "$ROOT_DIR/.restore-backup-path"
echo "回滚完成；/Applications/Vibe Island.app 未被触碰。"
