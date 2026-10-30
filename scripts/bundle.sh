#!/usr/bin/env bash
# Builds ShinyMac.app from the SwiftPM executable.
#   CONFIG=debug ./scripts/bundle.sh    # faster local builds
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP="build/ShinyMac.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ShinyMac" "$APP/Contents/MacOS/ShinyMac"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [[ -f Support/AppIcon.icns ]]; then
  cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Ad-hoc signature so macOS can track privacy permissions (e.g. Full Disk Access).
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
