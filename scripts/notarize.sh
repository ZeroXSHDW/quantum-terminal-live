#!/usr/bin/env bash
# Sign and notarize a Quantum Terminal Live DMG for distribution.
#
# Requires an Apple Developer ID (paid $99/yr account) and app-specific password.
# Provide credentials via environment variables:
#   APPLE_ID            your Apple Developer account email
#   APPLE_APP_PASSWORD  an app-specific password (appleid.apple.com)
#   APPLE_TEAM_ID       10-character team ID (from developer.apple.com)
#
# Usage:
#   make dmg
#   ./scripts/notarize.sh build/Quantum-Terminal-Live-3.1.2.dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DMG="${1:-}"
if [ -z "$DMG" ] || [ ! -f "$DMG" ]; then
  echo "usage: $0 <path-to-dmg>" >&2
  echo "       run 'make dmg' first" >&2
  exit 2
fi

: "${APPLE_ID:?set APPLE_ID to your Apple Developer email}"
: "${APPLE_APP_PASSWORD:?set APPLE_APP_PASSWORD to an app-specific password}"
: "${APPLE_TEAM_ID:?set APPLE_TEAM_ID to your team ID}"

IDENTITY="Developer ID Application: ($APPLE_TEAM_ID)"
PROFILE="qtl-notary"
NOTARY="xcrun notarytool"

echo "==> signing $DMG"
codesign --force --timestamp --options runtime \
  --sign "Developer ID Application" "$DMG"

echo "==> storing notary credentials (once)"
xcrun notarytool store-credentials "$PROFILE" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_PASSWORD"

echo "==> submitting for notarization"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> stapling ticket"
xcrun stapler staple "$DMG"

echo "==> verifying"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "done: $DMG is notarized and stapled"
