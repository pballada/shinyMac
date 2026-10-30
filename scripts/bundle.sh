#!/usr/bin/env bash
# Builds ShinyMac.app from the SwiftPM executable.
#   CONFIG=debug ./scripts/bundle.sh              # faster local builds
#   UNIVERSAL=1 SIGN_IDENTITY="Developer ID Application: …" ./scripts/bundle.sh
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP="build/ShinyMac.app"
ARCH_FLAGS=()
if [[ -n "${UNIVERSAL:-}" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ShinyMac" "$APP/Contents/MacOS/ShinyMac"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [[ -f Support/AppIcon.icns ]]; then
  cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  # Hardened runtime + secure timestamp, as notarization requires.
  codesign --force --options runtime --timestamp \
    --entitlements Support/ShinyMac.entitlements \
    --sign "$SIGN_IDENTITY" "$APP"
else
  # Ad-hoc signature so macOS can track privacy permissions (e.g. Full Disk Access).
  codesign --force --sign - "$APP" >/dev/null
fi
echo "Built $APP"
