#!/usr/bin/env bash
# Builds a universal, Developer ID–signed, notarized and stapled ShinyMac release.
#
#   ./scripts/release.sh 0.2.0
#
# One-time setup:
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode › Settings › Accounts › Manage Certificates › + › Developer ID Application).
#   2. Notary credentials stored as a keychain profile:
#      xcrun notarytool store-credentials notary --apple-id you@example.com --team-id TEAMID
#
# Override with SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" or NOTARY_PROFILE=name.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>}"
PROFILE="${NOTARY_PROFILE:-notary}"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')}"
if [[ -z "$IDENTITY" ]]; then
  echo "No Developer ID Application certificate found. See the setup notes at the top of this script." >&2
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Support/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD)" Support/Info.plist

UNIVERSAL=1 SIGN_IDENTITY="$IDENTITY" ./scripts/bundle.sh
codesign --verify --strict --verbose=2 build/ShinyMac.app

ZIP="build/ShinyMac-$VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent build/ShinyMac.app "$ZIP"
echo "Submitting to Apple's notary service (usually a few minutes)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

# Staple the ticket so the app opens offline, then re-zip the stapled app.
xcrun stapler staple build/ShinyMac.app
spctl --assess --type execute --verbose build/ShinyMac.app
rm -f "$ZIP"
ditto -c -k --keepParent build/ShinyMac.app "$ZIP"

echo
echo "Release ready: $ZIP"
echo "  version: $VERSION"
echo "  sha256:  $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
