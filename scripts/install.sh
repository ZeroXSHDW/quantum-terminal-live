#!/usr/bin/env bash
# Install Quantum Terminal Live for the current user (no sudo).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WITH_AERIAL=0
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --with-aerial) WITH_AERIAL=1 ;;
    --no-build) SKIP_BUILD=1 ;;
    -h|--help)
      cat <<'USAGE'
usage: install.sh [--with-aerial] [--no-build]

  --with-aerial  also register the loop with Aerial 4.1+ (single-entry playlist)
  --no-build     install the existing build/ output without rebuilding
USAGE
      exit 0
      ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: Quantum Terminal Live requires macOS." >&2
  exit 1
fi

BUILD="$ROOT/build"
APP_SRC="$BUILD/Quantum Terminal Live.app"
MOVIE_SRC="$ROOT/Assets/Quantum-Terminal-Live-30s.mov"
APP_DST="$HOME/Applications/Quantum Terminal Live.app"
MOVIE_DIR="$HOME/Movies/Quantum Terminal"
MOVIE_DST="$MOVIE_DIR/Quantum-Terminal-Live-30s.mov"
PLIST="$HOME/Library/LaunchAgents/com.user.QuantumTerminalLive.plist"
LABEL="com.user.QuantumTerminalLive"
UID_NUM="$(id -u)"

if [ "$SKIP_BUILD" -eq 0 ]; then
  "$ROOT/scripts/build.sh"
fi

if [ ! -d "$APP_SRC" ]; then
  echo "error: $APP_SRC not found; run ./scripts/build.sh" >&2
  exit 1
fi
if [ ! -f "$MOVIE_SRC" ]; then
  echo "error: $MOVIE_SRC not found; run ./scripts/make-assets.sh" >&2
  exit 1
fi

echo "==> stopping an existing agent"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
pkill -f "$APP_DST/Contents/MacOS/QuantumTerminalLive" 2>/dev/null || true

echo "==> installing app"
mkdir -p "$HOME/Applications"
if [ -e "$APP_DST" ]; then
  EXISTING_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
    "$APP_DST/Contents/Info.plist" 2>/dev/null || true)"
  if [ "$EXISTING_ID" != "com.user.QuantumTerminalLive" ]; then
    echo "error: refusing to replace an unrelated app at $APP_DST" >&2
    exit 1
  fi
  rm -rf "$APP_DST"
fi
ditto "$APP_SRC" "$APP_DST"
codesign --verify --strict "$APP_DST" 2>/dev/null || true

echo "==> installing LaunchAgent"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_DST/Contents/MacOS/QuantumTerminalLive</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>ThrottleInterval</key>
    <integer>5</integer>
</dict>
</plist>
PLIST
chmod 0644 "$PLIST"
plutil -lint "$PLIST" >/dev/null

launchctl bootstrap "gui/$UID_NUM" "$PLIST"
launchctl enable "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl kickstart -k "gui/$UID_NUM/$LABEL"

echo "==> installing movie"
mkdir -p "$MOVIE_DIR"
install -m 0644 "$MOVIE_SRC" "$MOVIE_DST.new"
mv -f "$MOVIE_DST.new" "$MOVIE_DST"

# The movie must be byte-identical to the source, otherwise the desktop and the
# screen saver drift out of sync and the 30-second loop loses its seamlessness.
if ! cmp -s "$MOVIE_SRC" "$MOVIE_DST"; then
  echo "warning: installed movie differs from source — re-run install.sh." >&2
fi

if [ "$WITH_AERIAL" -eq 1 ]; then
  echo "==> configuring Aerial"
  python3 "$ROOT/scripts/configure-aerial.py" --movie "$MOVIE_DST"
else
  echo "note: run ./scripts/install.sh --with-aerial to register the screen saver with Aerial."
fi

echo
echo "installed:"
echo "  app:   $APP_DST"
echo "  agent: $PLIST"
echo "  movie: $MOVIE_DST"
echo
echo "The live wallpaper starts at login and is running now."
echo "For the screen saver, select Aerial as the system wallpaper and use the"
echo "'Quantum Terminal' playlist."
