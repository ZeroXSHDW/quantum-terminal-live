#!/usr/bin/env bash
# Uninstall Quantum Terminal Live for the current user.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PURGE=0
for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    -h|--help)
      echo "usage: uninstall.sh [--purge]"
      echo "  --purge  also remove local movie files and the Aerial playlist"
      exit 0
      ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

LABEL="com.user.QuantumTerminalLive"
PLIST="$HOME/Library/LaunchAgents/com.user.QuantumTerminalLive.plist"
APP="$HOME/Applications/Quantum Terminal Live.app"

echo "==> stopping LaunchAgent"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$PLIST"

echo "==> removing app"
rm -rf "$APP"

if [ "$PURGE" -eq 1 ]; then
  echo "==> removing local movie"
  rm -rf "$HOME/Movies/Quantum Terminal"
  rm -f "/Users/Shared/Aerial/My Videos/Quantum-Terminal-Live-30s.mov"
  if [ -f "$ROOT/scripts/configure-aerial.py" ]; then
    python3 "$ROOT/scripts/configure-aerial.py" --remove || true
  fi
fi

echo "uninstalled."
