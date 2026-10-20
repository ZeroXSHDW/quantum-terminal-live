#!/usr/bin/env bash
# Regression smoke test: re-renders a reference frame and diffs it against the
# committed golden. The scene is fully deterministic (seeded RNG, fixed clock),
# so any change to the render — intended or not — flips this to a failure so it
# can be reviewed before shipping.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GOLDEN="$ROOT/tests/golden-frame.jpg"
NOW="$ROOT/build/golden-now.jpg"

"$ROOT/scripts/build.sh" >/dev/null
"$ROOT/build/RenderFrame" \
  "$ROOT/Assets/quantum-terminal-live-wallpaper-8k.png" \
  "$NOW" 1920 1200 8

if cmp -s "$GOLDEN" "$NOW"; then
  echo "golden frame OK"
else
  echo "golden frame CHANGED."
  echo "  committed: $GOLDEN"
  echo "  current:   $NOW"
  echo "Review the two frames; if the change is intended, refresh the golden with:"
  echo "  cp build/golden-now.jpg tests/golden-frame.jpg"
  exit 1
fi
