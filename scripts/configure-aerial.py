#!/usr/bin/env python3
"""Register the Quantum Terminal loop as a single-entry Aerial playlist.

Aerial 4.1 stores screen/video state in /Users/Shared/Aerial. This script:
  * copies the movie into Aerial's My Videos folder,
  * waits for Aerial to index it,
  * creates/updates a user playlist named "Quantum Terminal",
  * points every screen playlist at that one entry,
  * bumps the wallpaper-control generation so the extension reloads,
  * restarts the extension when the movie content changed.

It backs up playlists.json before changing anything. Aerial-version specific:
tested with Aerial 4.1.8 on macOS 26.
"""

from __future__ import annotations

import argparse
import filecmp
import json
import os
import shutil
import signal
import subprocess
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path

BASE = Path("/Users/Shared/Aerial")
MY_VIDEOS = BASE / "My Videos"
SOURCES = BASE / "Sources" / "My Videos"
ENTRIES = SOURCES / "entries.json"
PLAYLISTS = BASE / "playlists.json"
CONTROL = BASE / "wallpaper-control.json"
PLAYLIST_DIR = BASE / "Playlists"
INDEX = PLAYLIST_DIR / "_index.json"
AERIAL_APP = Path("/Applications/Aerial.app")
DARWIN_NAME = "com.glouel.aerial.wallpaper-control"
PLAYLIST_NAME = "Quantum Terminal"
MOVIE_NAME = "Quantum-Terminal-Live-30s.mov"
REFERENCE_EPOCH = 978307200.0  # 2001-01-01, Foundation's reference date


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return default


def write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")
    os.replace(tmp, path)


def now_reference() -> float:
    return time.time() - REFERENCE_EPOCH


def aerial_running() -> bool:
    return subprocess.run(["pgrep", "-x", "Aerial"],
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode == 0


def start_aerial() -> None:
    subprocess.run(["open", "-a", "Aerial"],
                   stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL,
                   check=False)


def copy_movie(movie: Path) -> tuple[Path, bool]:
    """Copy into My Videos. Returns (destination, content_changed)."""
    destination = MY_VIDEOS / movie.name
    MY_VIDEOS.mkdir(parents=True, exist_ok=True)
    if movie.resolve() == destination.resolve():
        return destination, False
    if (destination.exists()
            and destination.stat().st_size == movie.stat().st_size
            and filecmp.cmp(movie, destination, shallow=False)):
        return destination, False
    tmp = destination.with_suffix(destination.suffix + ".tmp")
    shutil.copy2(movie, tmp)
    os.replace(tmp, destination)
    return destination, True


def restart_extension() -> None:
    """Force Aerial's wallpaper extension to reopen the movie file."""
    status = read_json(BASE / "wallpaper-status.json", {})
    pid = status.get("pid")
    if not isinstance(pid, int) or pid <= 1:
        return
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return
    except PermissionError:
        print("warning: could not restart the Aerial wallpaper extension", file=sys.stderr)
        return
    print("==> restarting Aerial wallpaper extension")
    for _ in range(20):
        time.sleep(0.5)
        fresh = read_json(BASE / "wallpaper-status.json", {})
        if fresh.get("pid") != pid:
            return


def wait_for_asset(movie: Path, timeout: float = 30.0):
    """Wait for Aerial's MyVideosWatcher to index the file."""
    deadline = time.time() + timeout
    while time.time() < deadline:
        entries = read_json(ENTRIES, {})
        for asset in entries.get("assets", []):
            path = asset.get("url-4K-SDR") or asset.get("url") or ""
            if path and Path(path).name == movie.name:
                return asset
        time.sleep(0.5)
    return None


def ensure_index(name: str, entry_count: int = 1):
    index = read_json(INDEX, {"version": 1, "playlists": []})
    playlists = index.setdefault("playlists", [])
    for playlist in playlists:
        if playlist.get("name") == name:
            playlist["entryCount"] = entry_count
            write_json(INDEX, index)
            return playlist["id"]
    playlist_id = str(uuid.uuid4()).upper()
    order = (max((p.get("order", 0) for p in playlists), default=-1) + 1)
    playlists.append({"id": playlist_id, "name": name,
                      "entryCount": entry_count, "order": order})
    write_json(INDEX, index)
    return playlist_id


def bump_control() -> None:
    control = read_json(CONTROL, None)
    if not isinstance(control, dict):
        return
    control["version"] = int(control.get("version", 0)) + 1
    for screen in control.get("screens", {}).values():
        screen["playlistGeneration"] = int(screen.get("playlistGeneration", 0)) + 1
    write_json(CONTROL, control)
    notify = shutil.which("notifyutil")
    if notify:
        subprocess.run([notify, "-p", DARWIN_NAME],
                       stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL,
                       check=False)


def install(movie: Path, force_reload: bool = False) -> int:
    if not AERIAL_APP.exists():
        print("error: Aerial.app was not found in /Applications.", file=sys.stderr)
        return 2
    if not PLAYLISTS.exists():
        print(f"error: {PLAYLISTS} not found. Launch Aerial once first.", file=sys.stderr)
        return 2

    if not aerial_running():
        print("==> starting Aerial")
        start_aerial()
        time.sleep(2)

    print(f"==> copying {movie.name} into {MY_VIDEOS}")
    destination, changed = copy_movie(movie)

    print("==> waiting for Aerial to index the movie")
    asset = wait_for_asset(destination)
    if not asset:
        print("error: Aerial did not index the movie.", file=sys.stderr)
        print("       Open Aerial → Video Library → My Videos, then re-run.", file=sys.stderr)
        return 3

    entry = {
        "videoId": asset["id"],
        "videoName": "My Videos",
        "secondaryName": asset.get("title", destination.name),
        "duration": 30.0,
    }

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = BASE / f"playlists.json.qtl-backup-{stamp}"
    if not backup.exists():
        shutil.copy2(PLAYLISTS, backup)
        print(f"==> backup: {backup}")

    playlist_id = ensure_index(PLAYLIST_NAME, 1)
    manifest = {
        "id": playlist_id,
        "name": PLAYLIST_NAME,
        "createdAt": now_reference(),
        "cycleMode": 0,
        "entries": [entry],
    }
    write_json(PLAYLIST_DIR / f"{playlist_id}.json", manifest)

    state = read_json(PLAYLISTS, {"version": 1, "sharedPlaylist": None,
                                  "screenPlaylists": {}})
    filters = [f"userPlaylist:{playlist_id}"]
    targets = []
    if isinstance(state.get("sharedPlaylist"), dict):
        targets.append(state["sharedPlaylist"])
    else:
        state["sharedPlaylist"] = {}
        targets.append(state["sharedPlaylist"])
    for playlist in state.get("screenPlaylists", {}).values():
        targets.append(playlist)

    for playlist in targets:
        playlist["entries"] = [entry]
        playlist["currentIndex"] = 0
        playlist["playbackTimestamp"] = 0.0
        playlist["filterMode"] = -1
        playlist["filterStrings"] = filters
        playlist["generatedAt"] = now_reference()
        playlist["cycleMode"] = 0

    write_json(PLAYLISTS, state)
    bump_control()
    if changed or force_reload:
        restart_extension()

    print("==> Aerial playlist ready")
    print(f"    name: {PLAYLIST_NAME}")
    print(f"    id:   {playlist_id}")
    print(f"    video: {entry['secondaryName']} ({entry['duration']:.0f}s)")
    print("    Select Aerial as the system wallpaper / screen saver in System Settings.")
    return 0


def remove() -> int:
    index = read_json(INDEX, {"version": 1, "playlists": []})
    playlists = index.get("playlists", [])
    ours = [p for p in playlists if p.get("name") == PLAYLIST_NAME]
    for playlist in ours:
        path = PLAYLIST_DIR / f"{playlist['id']}.json"
        path.unlink(missing_ok=True)
        print(f"removed playlist: {playlist['id']}")
    index["playlists"] = [p for p in playlists if p.get("name") != PLAYLIST_NAME]
    write_json(INDEX, index)

    backups = sorted(BASE.glob("playlists.json.qtl-backup-*"))
    if backups:
        shutil.copy2(backups[0], PLAYLISTS)
        print(f"restored: {backups[0].name}")
    bump_control()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--movie", type=Path)
    parser.add_argument("--remove", action="store_true")
    parser.add_argument("--reload", action="store_true",
                        help="force Aerial's wallpaper extension to reopen the movie")
    args = parser.parse_args()

    if args.remove:
        return remove()
    if not args.movie:
        parser.error("--movie is required unless --remove is used")
    if not args.movie.exists():
        print(f"error: movie not found: {args.movie}", file=sys.stderr)
        return 2
    return install(args.movie, force_reload=args.reload)


if __name__ == "__main__":
    sys.exit(main())
