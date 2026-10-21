#!/usr/bin/env bash
# Regression smoke test: re-renders reference frames and diffs them against the
# committed goldens. The scene is fully deterministic (seeded RNG, fixed clock),
# so any change to the render — intended or not — flips this to a failure so it
# can be reviewed before shipping.
#
# Frames covered:
#   t=8.0   idle scene (rain, searchlight, telemetry)
#   t=15.4  alert window (red wash, pylon strobes, DEFCON banner)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

RENDERER="$ROOT/build/RenderFrame"
declare -a TIMES=(8.0 15.4)
declare -a NAMES=(idle alert)

"$ROOT/scripts/build.sh" >/dev/null

rc=0
for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  time="${TIMES[$i]}"
  golden="$ROOT/tests/golden-$name.jpg"
  now="$ROOT/build/golden-$name-now.jpg"

  "$RENDERER" "$ROOT/Assets/quantum-terminal-live-wallpaper-8k.png" "$now" 1920 1200 "$time"

  if [ ! -f "$golden" ]; then
    echo "golden $name MISSING — first run? Commit it with:"
    echo "  cp $now $golden"
    rc=1
  elif cmp -s "$golden" "$now"; then
    echo "golden $name OK"
  else
    echo "golden $name CHANGED."
    echo "  committed: $golden"
    echo "  current:   $now"
    echo "Review the two frames; if the change is intended, refresh with:"
    echo "  cp $now $golden"
    rc=1
  fi
done

if [ "$rc" -ne 0 ]; then exit "$rc"; fi
