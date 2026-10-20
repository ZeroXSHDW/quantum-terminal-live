# Installation

## Requirements

- Apple Silicon Mac (arm64)
- macOS 14 or later
- Xcode Command Line Tools: `xcode-select --install`
- Optional: Aerial 4.1+ for the screen saver

The app is an accessory (`LSUIElement`), so it has no Dock icon and no menu bar
item. It is controlled through launchd.

## Install

```sh
./scripts/install.sh
```

This runs `scripts/build.sh`, then:

1. Installs `Quantum Terminal Live.app` to `~/Applications`.
2. Writes `~/Library/LaunchAgents/com.user.QuantumTerminalLive.plist`.
3. Boots the agent out and back in, then kickstarts it.
4. Copies the loop to `~/Movies/Quantum Terminal/`.

To register the screen saver with Aerial as well:

```sh
./scripts/install.sh --with-aerial
```

## Aerial screen saver

`scripts/configure-aerial.py` targets Aerial 4.1's on-disk format:

- `/Users/Shared/Aerial/My Videos/` — local videos
- `/Users/Shared/Aerial/Sources/My Videos/entries.json` — indexed assets
- `/Users/Shared/Aerial/playlists.json` — shared and per-screen playlists
- `/Users/Shared/Aerial/wallpaper-control.json` — extension control state
- `/Users/Shared/Aerial/Playlists/` — user-playlist manifests

It creates a user playlist named **Quantum Terminal** with one 30-second entry,
then points the shared and per-screen playlists at `filterMode = -1`
(`userPlaylist:<uuid>`). It backs up `playlists.json` as
`playlists.json.qtl-backup-<timestamp>` before writing, and bumps the control
generation plus posts `com.glouel.aerial.wallpaper-control` so the extension
reloads without a logout. If the movie content changed, it also restarts
Aerial's wallpaper extension so the new file is actually reopened.

The installer does **not** change the system Wallpaper/Screen Saver choice.
Select Aerial in System Settings → Wallpaper. On macOS 26 both the Desktop and
Idle slots must use `com.glouel.Aerial-App.Aerial4WallpaperExtension`.

Aerial's global playback speed still applies. At the default `0.333×`, the 30 s
loop plays over roughly 90 s; set Aerial to `1×` if you want the saver to match
the live desktop timing.

## Manual build

```sh
./scripts/build.sh
```

Products:

```
build/QuantumTerminalLive
build/QuantumLoopMaker
build/RenderArtwork
build/RenderFrame
build/IconMaker
build/Quantum Terminal Live.app
```

The app bundle also contains the freshly rendered `Contents/Resources/AppIcon.icns`.
The app is ad-hoc signed. macOS may show a Gatekeeper prompt if you move it to
another Mac; this project is intended for local source builds.

## Regenerate assets

```sh
./scripts/make-assets.sh
```

This writes the 8K PNG and the 30-second movie, then rebuilds the app bundle so
its bundled master and code signature match the new assets. It refuses to leave
a movie at or above 100 MiB, because GitHub rejects individual files at that
size. Use a Release asset or Git LFS if you need a higher bitrate.

Regenerate the app icon on its own:

```sh
./scripts/make-icon.sh
```

This writes `Assets/AppIcon.icns` and `Assets/AppIcon-1024.png`; the build script
renders the same icon into the bundle automatically.

Fast preview only (no assets touched):

```sh
./scripts/make-assets.sh --preview
```

## Service control

```sh
# status
launchctl print gui/$(id -u)/com.user.QuantumTerminalLive

# restart
launchctl kickstart -k gui/$(id -u)/com.user.QuantumTerminalLive

# stop until next login
launchctl bootout gui/$(id -u)/com.user.QuantumTerminalLive
```

Because the agent uses `KeepAlive`, quitting the process manually causes launchd
to restart it after a few seconds.

## Uninstall

```sh
./scripts/uninstall.sh          # app + LaunchAgent
./scripts/uninstall.sh --purge  # also local movie and Aerial playlist
```

`--purge` removes the movie from `~/Movies/Quantum Terminal/` and from Aerial's
`My Videos`, removes the Quantum Terminal user playlist, and restores the
earliest `playlists.json.qtl-backup-*` backup if one exists.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| No live wallpaper | `launchctl print gui/$(id -u)/com.user.QuantumTerminalLive`; run the app binary directly to see fatal errors. |
| Desktop icons hidden | Ensure the window level is `desktopWindow`; older builds used `-100`. |
| Screen saver not Quantum | Aerial must be the system wallpaper. Check the **Quantum Terminal** playlist in Aerial. |
| Aerial shows the old movie | Re-run `install.sh --with-aerial`; it bumps the control generation and forces a reload. |
| Movie too large for GitHub | Regenerate at 22 Mbps, use a Release asset, or Git LFS. |
| Build fails on a new Mac | `xcode-select --install`; confirm `swiftc --version`. |
