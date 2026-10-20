#!/usr/bin/env bash
# Render and install the Quantum Terminal app icon.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="$ROOT/build"
ICONSET="$BUILD/AppIcon.iconset"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "error: swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi
if ! command -v iconutil >/dev/null 2>&1; then
  echo "error: iconutil not found (part of macOS)." >&2
  exit 1
fi

mkdir -p "$BUILD/icon" "$BUILD/.module-cache"
export TMPDIR="$BUILD/.tmp"
mkdir -p "$TMPDIR"
cp Sources/IconMaker.swift "$BUILD/icon/main.swift"

TARGET="$(uname -m)-apple-macosx14.0"
swiftc -O -target "$TARGET" -module-cache-path "$BUILD/.module-cache" \
  "$BUILD/icon/main.swift" -o "$BUILD/IconMaker" \
  -framework AppKit -framework CoreGraphics

rm -rf "$ICONSET"
"$BUILD/IconMaker" "$ICONSET"

mkdir -p Assets
iconutil -c icns "$ICONSET" -o "$BUILD/AppIcon.icns"
cp "$BUILD/AppIcon.icns" Assets/AppIcon.icns
cp "$ICONSET/icon_512x512@2x.png" Assets/AppIcon-1024.png

echo "icon:"
echo "  $ROOT/Assets/AppIcon.icns"
echo "  $ROOT/Assets/AppIcon-1024.png"
