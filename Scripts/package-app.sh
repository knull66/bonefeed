#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Bonefeed"
DIST="$ROOT/Dist"
APP="$DIST/$APP_NAME.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
INSTALL_DIR="${HOME}/Applications"
INSTALL_APP="$INSTALL_DIR/$APP_NAME.app"

cd "$ROOT"
swift build -c release

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"
cp "$ROOT/.build/release/Bonefeed" "$BIN_DIR/$APP_NAME"
cp "$ROOT/Support/Info.plist" "$APP/Contents/Info.plist"

# App icon (skull logo)
if [[ -f "$ROOT/Support/AppIcon/AppIcon.icns" ]]; then
  cp "$ROOT/Support/AppIcon/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi
if [[ -f "$ROOT/Support/AppIcon/AppIcon.png" ]]; then
  cp "$ROOT/Support/AppIcon/AppIcon.png" "$RES_DIR/AppIcon.png"
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"

# Ad-hoc sign + clear quarantine so Notification Center recognizes the bundle.
codesign --force --deep --sign - "$APP" 2>/dev/null || true
xattr -cr "$APP" 2>/dev/null || true

# Install to ~/Applications — external volumes often don't show in Notifications.
mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_APP"
cp -R "$APP" "$INSTALL_APP"
codesign --force --deep --sign - "$INSTALL_APP" 2>/dev/null || true
xattr -cr "$INSTALL_APP" 2>/dev/null || true

echo "Built: $APP"
echo "Installed: $INSTALL_APP"
