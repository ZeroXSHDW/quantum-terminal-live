#!/usr/bin/env bash
# Build Quantum Terminal Live from source.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="$ROOT/build"
APP="$BUILD/Quantum Terminal Live.app"
ASSET="$ROOT/Assets/quantum-terminal-live-wallpaper-8k.png"

if ! command -v swiftc >/dev/null 2>&1; then
  echo "error: swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

if [ ! -f "$ASSET" ]; then
  echo "error: missing $ASSET" >&2
  echo "       run ./scripts/make-assets.sh to generate it" >&2
  exit 1
fi

mkdir -p "$BUILD/live" "$BUILD/loop" "$BUILD/artwork" "$BUILD/frame" "$BUILD/icon" \
         "$BUILD/.module-cache" "$BUILD/.tmp"
export TMPDIR="$BUILD/.tmp"
export CLANG_MODULE_CACHE_PATH="$BUILD/.module-cache"

# swiftc requires top-level code to live in a file named main.swift when
# compiling multiple files, so stage each executable's entry point.
cp Sources/QuantumTerminalLive.swift "$BUILD/live/main.swift"
cp Sources/QuantumLoopMaker.swift "$BUILD/loop/main.swift"
cp Sources/RenderArtwork.swift "$BUILD/artwork/main.swift"
cp Sources/RenderFrame.swift "$BUILD/frame/main.swift"
cp Sources/IconMaker.swift "$BUILD/icon/main.swift"

TARGET="$(uname -m)-apple-macosx14.0"
SWIFT=(swiftc -O -target "$TARGET" -module-cache-path "$BUILD/.module-cache")

echo "==> QuantumTerminalLive"
"${SWIFT[@]}" Sources/QuantumScene.swift "$BUILD/live/main.swift" \
  -o "$BUILD/QuantumTerminalLive" \
  -framework AppKit -framework QuartzCore -framework ImageIO

echo "==> QuantumLoopMaker"
"${SWIFT[@]}" Sources/QuantumScene.swift "$BUILD/loop/main.swift" \
  -o "$BUILD/QuantumLoopMaker" \
  -framework AVFoundation -framework AppKit -framework CoreGraphics -framework CoreVideo

echo "==> RenderArtwork"
"${SWIFT[@]}" Sources/QuantumArtwork.swift "$BUILD/artwork/main.swift" \
  -o "$BUILD/RenderArtwork" \
  -framework AppKit -framework CoreGraphics

echo "==> RenderFrame"
"${SWIFT[@]}" Sources/QuantumArtwork.swift Sources/QuantumScene.swift "$BUILD/frame/main.swift" \
  -o "$BUILD/RenderFrame" \
  -framework AppKit -framework CoreGraphics

echo "==> IconMaker"
"${SWIFT[@]}" "$BUILD/icon/main.swift" \
  -o "$BUILD/IconMaker" \
  -framework AppKit -framework CoreGraphics

echo "==> app icon"
rm -rf "$BUILD/AppIcon.iconset"
"$BUILD/IconMaker" "$BUILD/AppIcon.iconset" >/dev/null
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"

echo "==> app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/QuantumTerminalLive" "$APP/Contents/MacOS/QuantumTerminalLive"
cp "$ASSET" "$APP/Contents/Resources/quantum-terminal-live-wallpaper-8k.png"
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp Sources/Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP" >/dev/null 2>&1 || {
    echo "warning: ad-hoc codesign failed; the app will still run locally" >&2
  }
fi

echo "built:"
echo "  $APP"
echo "  $BUILD/QuantumLoopMaker"
echo "  $BUILD/RenderArtwork"
echo "  $BUILD/RenderFrame"
echo "  $BUILD/IconMaker"
