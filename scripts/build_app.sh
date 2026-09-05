#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${(%):-%N}")/.." && pwd)"
APP_NAME="Vibe Island Menu Spacer.app"
PRODUCT_NAME="VibeIslandMenuSpacer"
ARTIFACTS_DIR="$ROOT_DIR/.artifacts"
APP_DIR="$ARTIFACTS_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"

cd "$ROOT_DIR"
swift test
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
BIN_PATH="$(swift build -c release --show-bin-path)/$PRODUCT_NAME"
cp "$BIN_PATH" "$CONTENTS_DIR/MacOS/$PRODUCT_NAME"
chmod 755 "$CONTENTS_DIR/MacOS/$PRODUCT_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>Vibe Island Menu Spacer</string>
  <key>CFBundleExecutable</key>
  <string>VibeIslandMenuSpacer</string>
  <key>CFBundleIdentifier</key>
  <string>local.vibeisland.menu-spacer</string>
  <key>CFBundleName</key>
  <string>Vibe Island Menu Spacer</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

# Accessibility grants are bound to the app's designated code requirement.
# An ad-hoc signature changes its cdhash after every rebuild and makes macOS
# treat the same bundle path as a new client. Prefer a stable local development
# identity when one exists; keep ad-hoc only as a portable build fallback.
SIGN_IDENTITY="${VIBE_ISLAND_CODESIGN_IDENTITY:-$(
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' \
    | head -1
)}"
[[ -n "$SIGN_IDENTITY" ]] || SIGN_IDENTITY="-"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"
echo "$APP_DIR"
