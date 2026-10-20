#!/usr/bin/env bash
# Regenerate the 8K master and the 30-second screen-saver loop.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD="$ROOT/build"
ASSETS="$ROOT/Assets"
PNG="$ASSETS/quantum-terminal-live-wallpaper-8k.png"
MOV="$ASSETS/Quantum-Terminal-Live-30s.mov"
MODE="full"

case "${1:-}" in
  --preview) MODE="preview" ;;
  "" ) ;;
  -h|--help)
    echo "usage: $0 [--preview]"
    echo "  --preview  render 1920x1200 previews into build/ only"
    exit 0
    ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
esac

"$ROOT/scripts/build.sh"

if [ "$MODE" = "preview" ]; then
  mkdir -p "$BUILD"
  "$BUILD/RenderArtwork" "$BUILD/preview-wallpaper.png" 1920 1200
  "$BUILD/RenderFrame" "$BUILD/preview-wallpaper.png" "$BUILD/preview.jpg" 1920 1200 15.4
  echo "previews:"
  echo "  $BUILD/preview-wallpaper.png"
  echo "  $BUILD/preview.jpg"
  exit 0
fi

mkdir -p "$ASSETS" "$ROOT/docs"

echo "==> 8K master (7680x4800)"
"$BUILD/RenderArtwork" "$PNG" 7680 4800

echo "==> 30s HEVC loop (this takes ~7 minutes)"
"$BUILD/QuantumLoopMaker" "$PNG" "$MOV"

echo "==> preview frames"
"$BUILD/RenderFrame" "$PNG" "$ROOT/docs/preview.jpg" 1920 1200 15.4
"$BUILD/RenderFrame" "$PNG" "$BUILD/preview-idle.jpg" 1920 1200 8

SIZE=$(stat -f%z "$MOV" 2>/dev/null || stat -c%s "$MOV")
LIMIT=$((100 * 1024 * 1024))
echo "movie: $MOV ($SIZE bytes)"
if [ "$SIZE" -ge "$LIMIT" ]; then
  echo "error: movie is at or above GitHub's 100 MiB file limit." >&2
  echo "       Lower AVVideoAverageBitRateKey in Sources/QuantumLoopMaker.swift" >&2
  echo "       or publish the movie as a Release asset / use Git LFS." >&2
  exit 1
fi

# build.sh ran before the new master existed, so refresh the app bundle now
# that the PNG (and its ad-hoc signature) are current.
echo "==> refresh app bundle with the new master"
"$ROOT/scripts/build.sh" >/dev/null

echo "asset generation complete."
