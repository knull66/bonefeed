#!/usr/bin/env bash
# Sign with Developer ID, notarize, staple, and build a DMG for web distribution.
# Prereqs: Apple Developer Program + notarytool profile. See Support/SHIP_WEB.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Bonefeed"
DIST="$ROOT/Dist"
APP="$DIST/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Support/Info.plist" 2>/dev/null || echo "1.0.0")"
DMG="$DIST/${APP_NAME}-${VERSION}.dmg"
ZIP="$DIST/${APP_NAME}-${VERSION}-notarize.zip"

SIGN_IDENTITY="${BONEFEED_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${BONEFEED_NOTARY_PROFILE:-bonefeed-notary}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "Set BONEFEED_SIGN_IDENTITY to your Developer ID Application identity."
  echo "List with: security find-identity -v -p codesigning | grep 'Developer ID Application'"
  exit 1
fi

echo "==> Building ad-hoc package first"
"$ROOT/Scripts/package-app.sh"

echo "==> Signing with Developer ID (Hardened Runtime)"
codesign --force --deep --options runtime \
  --sign "$SIGN_IDENTITY" \
  --timestamp \
  "$APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dv --verbose=4 "$APP" 2>&1 | head -40

echo "==> Zipping for notarytool"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to Apple notarization (profile: $NOTARY_PROFILE)"
xcrun notarytool submit "$ZIP" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "==> Gatekeeper assess"
spctl -a -vv "$APP" || true

echo "==> Building DMG"
rm -f "$DMG"
STAGE="$DIST/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"
rm -f "$ZIP"

echo ""
echo "Notarized app: $APP"
echo "DMG:           $DMG"
echo "Next: upload DMG and set downloadUrl in Web/commerce-config.js"
echo "Also re-install for local test:"
echo "  cp -R \"$APP\" \"$HOME/Applications/$APP_NAME.app\""
