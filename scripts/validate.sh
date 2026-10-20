#!/usr/bin/env bash
# Repository hygiene checks. Runs on macOS (CI uses a macOS runner).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail=0
note() { printf '  %s\n' "$*"; }
bad() { printf '  ERROR: %s\n' "$*" >&2; fail=1; }

echo "== required files =="
for f in README.md CHANGELOG.md LICENSE .gitignore .gitattributes Makefile \
         Sources/QuantumArtwork.swift Sources/QuantumScene.swift \
         Sources/QuantumTerminalLive.swift Sources/QuantumLoopMaker.swift \
         Sources/IconMaker.swift \
         Sources/RenderArtwork.swift Sources/RenderFrame.swift Sources/Info.plist \
         Assets/quantum-terminal-live-wallpaper-8k.png \
         Assets/Quantum-Terminal-Live-30s.mov \
         Assets/AppIcon.icns Assets/AppIcon-1024.png \
         scripts/build.sh scripts/install.sh scripts/uninstall.sh \
         scripts/make-assets.sh scripts/make-icon.sh scripts/configure-aerial.py \
         scripts/golden-test.sh tests/golden-frame.jpg \
         .github/workflows/ci.yml; do
  if [ -f "$f" ]; then note "ok $f"; else bad "missing $f"; fi
done

echo "== legacy / junk files =="
for f in .DS_Store QuantumTerminalLive QuantumLoopMaker QuantumLoopMaker-compiled \
         Quantum-Terminal-Screener-High-Res.mov install_quantum_terminal.sh \
         install-quantum-terminal.sh create-screener.sh generate-qtl-screener.sh; do
  if [ -e "$f" ]; then bad "legacy file present: $f"; fi
done
for d in Contents Output; do
  if [ -e "$d" ]; then bad "legacy directory present: $d"; fi
done
if find . -name '.DS_Store' -not -path './.git/*' | grep -q .; then
  bad ".DS_Store found"
fi

echo "== shell syntax =="
for f in scripts/*.sh; do
  bash -n "$f"
  note "ok $f"
done

echo "== python syntax =="
python3 - <<'PY'
import pathlib, sys
ok = True
for path in sorted(pathlib.Path("scripts").glob("*.py")):
    try:
        compile(path.read_text(), str(path), "exec")
    except SyntaxError as exc:
        print(f"  ERROR: {path}: {exc}", file=sys.stderr)
        ok = False
print("  python syntax OK" if ok else "")
sys.exit(0 if ok else 1)
PY

echo "== plist =="
if command -v plutil >/dev/null 2>&1; then
  plutil -lint Sources/Info.plist
else
  note "plutil unavailable; skipped"
fi

echo "== absolute user paths =="
if grep -RIn --exclude-dir=.git --exclude-dir=build --exclude=validate.sh '/Users/user' . >/tmp/qtl-abs-paths.$$ 2>/dev/null; then
  cat /tmp/qtl-abs-paths.$$ >&2
  bad "hard-coded /Users/user path found"
fi
rm -f /tmp/qtl-abs-paths.$$

echo "== file size limit (100 MiB) =="
python3 - <<'PY'
import pathlib, sys
limit = 100 * 1024 * 1024
bad = []
for path in pathlib.Path(".").rglob("*"):
    if ".git" in path.parts or "build" in path.parts or not path.is_file():
        continue
    size = path.stat().st_size
    if size >= limit:
        bad.append((str(path), size))
for path, size in bad:
    print(f"  ERROR: {path} is {size} bytes", file=sys.stderr)
if not bad:
    print("  all files below 100 MiB")
sys.exit(1 if bad else 0)
PY

echo "== README links =="
python3 scripts/check-readme-links.py

echo "== asset sanity =="
if command -v sips >/dev/null 2>&1; then
  W=$(sips -g pixelWidth Assets/quantum-terminal-live-wallpaper-8k.png 2>/dev/null | awk '/pixelWidth/ {print $2}')
  H=$(sips -g pixelHeight Assets/quantum-terminal-live-wallpaper-8k.png 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [ "$W" = "7680" ] && [ "$H" = "4800" ]; then
    note "PNG 7680x4800"
  else
    bad "PNG is ${W}x${H}, expected 7680x4800"
  fi

  IW=$(sips -g pixelWidth Assets/AppIcon-1024.png 2>/dev/null | awk '/pixelWidth/ {print $2}')
  IH=$(sips -g pixelHeight Assets/AppIcon-1024.png 2>/dev/null | awk '/pixelHeight/ {print $2}')
  if [ "$IW" = "1024" ] && [ "$IH" = "1024" ]; then
    note "icon PNG 1024x1024"
  else
    bad "icon PNG is ${IW}x${IH}, expected 1024x1024"
  fi
fi

echo "== executable bits =="
for f in scripts/*.sh scripts/*.py; do
  if [ -x "$f" ]; then note "ok $f"; else bad "not executable: $f"; fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "validate: FAILED" >&2
  exit 1
fi
echo "validate: OK"
