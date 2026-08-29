#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
APP_NAME="Vibe Island Menu Spacer.app"
SOURCE="$ROOT_DIR/.artifacts/$APP_NAME"
DEST_DIR="$HOME/Applications"
DEST="$DEST_DIR/$APP_NAME"
BACKUP_DIR="$ROOT_DIR/.rollback"
LAUNCH_AGENT_LABEL="local.vibeisland.menu-spacer.autostart"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/$LAUNCH_AGENT_LABEL.plist"
UID_VALUE="$(id -u)"

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

mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$LAUNCH_AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCH_AGENT_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$DEST/Contents/MacOS/VibeIslandMenuSpacer</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>ProcessType</key>
  <string>Interactive</string>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/VibeIslandMenuSpacer.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/VibeIslandMenuSpacer.log</string>
</dict>
</plist>
PLIST
plutil -lint "$LAUNCH_AGENT" >/dev/null
launchctl bootout "gui/$UID_VALUE/$LAUNCH_AGENT_LABEL" 2>/dev/null || true
pkill -TERM -x VibeIslandMenuSpacer 2>/dev/null || true
launchctl bootstrap "gui/$UID_VALUE" "$LAUNCH_AGENT"
launchctl enable "gui/$UID_VALUE/$LAUNCH_AGENT_LABEL"
echo "已安装到：$DEST"
echo "已启用登录启动；仅在真实菜单栏图标进入居中紧凑区域时创建占位。"
