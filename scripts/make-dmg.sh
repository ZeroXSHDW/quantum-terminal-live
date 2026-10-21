#!/usr/bin/env bash
# Builds a distributable, unsigned DMG containing the app with a standard
# drag-to-Applications layout. Notarization is a separate step that requires an
# Apple Developer ID; this produces a shareable disk image without one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP="$ROOT/build/Quantum Terminal Live.app"
STAGE="$ROOT/build/dmg-staging"
NAME="Quantum Terminal Live"
VOLUME="Quantum Terminal Live"
VERSION=""
DMG=""

[ -d "$APP" ] || { "$ROOT/scripts/build.sh" >/dev/null; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  "$APP/Contents/Info.plist")"
DMG="$ROOT/build/Quantum-Terminal-Live-${VERSION}.dmg"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$DMG"
hdiutil create -volname "$VOLUME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "wrote $DMG (${VERSION})"
