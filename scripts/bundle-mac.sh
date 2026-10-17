#!/usr/bin/env bash
# Build the garminy Mac companion, sign it, install it and start it.
# Usage: scripts/bundle-mac.sh [--no-install]
#
# Installs "garminy Companion.app" to ~/Applications and links garminy-hook into
# ~/.local/bin. Signs with the "garminy-local" identity when it exists (create it once
# with scripts/mac-signing-identity.sh) so macOS permissions survive rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=1
case "${1:-}" in
  --no-install) INSTALL=0 ;;
  "") ;;
  *) echo "usage: scripts/bundle-mac.sh [--no-install]" >&2; exit 2 ;;
esac

swift build -c release --package-path mac 2>&1 | tail -1
BIN="$(swift build -c release --package-path mac --show-bin-path)"

APP="mac/build/garminy Companion.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/GarminyCompanion" "$BIN/garminy-hook" "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.github.williamthepoon.garminy.companion</string>
  <key>CFBundleName</key><string>garminy Companion</string>
  <key>CFBundleExecutable</key><string>GarminyCompanion</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>garminy uses Bluetooth to talk to your fēnix 7.</string>
  <key>NSLocationWhenInUseUsageDescription</key><string>garminy can use this Mac's location for the weather shown on your watch.</string>
  <key>NSLocationUsageDescription</key><string>garminy can use this Mac's location for the weather shown on your watch.</string>
  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key><string>garminy uses this Mac's location for the weather shown on your watch.</string>
  <key>NSLocationAlwaysUsageDescription</key><string>garminy uses this Mac's location for the weather shown on your watch.</string>
</dict></plist>
PLIST

IDENTITY=-
if security find-identity -p codesigning 2>/dev/null | grep -q '"garminy-local"'; then
  IDENTITY=garminy-local
else
  echo "warning: no garminy-local signing identity; signing ad-hoc, so macOS may ask for Bluetooth again after each rebuild." >&2
  echo "         Run scripts/mac-signing-identity.sh once to fix this." >&2
fi
# The hardened runtime blocks Location requests unless the app declares this entitlement.
ENT="$(mktemp)"; trap 'rm -f "$ENT"' EXIT
cat > "$ENT" <<ENTS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.personal-information.location</key><true/>
</dict></plist>
ENTS
codesign --force --options runtime -s "$IDENTITY" "$APP/Contents/MacOS/garminy-hook"
codesign --force --options runtime --entitlements "$ENT" -s "$IDENTITY" "$APP"
echo "Built $APP (signed: $IDENTITY)"

[ "$INSTALL" = 1 ] || exit 0

DEST="$HOME/Applications/garminy Companion.app"
pkill -x GarminyCompanion 2>/dev/null || true
mkdir -p "$HOME/Applications" "$HOME/.local/bin"
rm -rf "$DEST"
cp -R "$APP" "$DEST"
ln -sf "$DEST/Contents/MacOS/garminy-hook" "$HOME/.local/bin/garminy-hook"
open "$DEST"
echo "Installed $DEST and ~/.local/bin/garminy-hook"
