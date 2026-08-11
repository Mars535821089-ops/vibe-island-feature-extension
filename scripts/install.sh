#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
APP_NAME="Vibe Island Menu Spacer.app"
SOURCE="$ROOT_DIR/.artifacts/$APP_NAME"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/$APP_NAME"
BACKUP_DIR="$ROOT_DIR/.rollback"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null
mkdir -p "$DEST_DIR"
if [[ -e "$DEST" && ! -f "$ROOT_DIR/.installed-path" ]]; then
  mkdir -p "$BACKUP_DIR"
  BACKUP="$BACKUP_DIR/${APP_NAME%.app}-$(date +%Y%m%d-%H%M%S).app"
  mv "$DEST" "$BACKUP"
  echo "$BACKUP" > "$ROOT_DIR/.restore-backup-path"
  echo "已保留旧版本：$BACKUP"
fi
ditto "$SOURCE" "$DEST"
codesign --verify --deep --strict "$DEST"
echo "$DEST" > "$ROOT_DIR/.installed-path"
echo "已安装到：$DEST"
echo "开机启动暂未启用；仅在真实菜单栏图标进入居中紧凑区域时创建占位。"
