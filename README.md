# Quantum Terminal Live

**Private repository.** Owner: [ZeroXSHDW](https://github.com/ZeroXSHDW).

An 8K blue/violet cyberdeck wallpaper and matching animated macOS screen saver.

The project is designed for a dark operator-console aesthetic: a centered secure core, architectural circuit layers, reflective floor geometry, restrained telemetry motion, and no green Matrix rain, falling code, text, logos, or watermark.

## Included

- `Assets/quantum-terminal-live-wallpaper-8k.png` — 7,680 × 4,800 sRGB wallpaper master.
- `Assets/Quantum-Terminal-Secure-Core-8K-30fps-30s.mov` — 7,680 × 4,800 HEVC screen saver loop, 30 fps, 30 seconds.
- `Sources/QuantumTerminalLive.swift` — borderless animated wallpaper layer with power-aware frame pacing, sleep/wake pausing, display hot-plug rebuilding, orbital beacons, telemetry packets, scan sweep, and edge vignette.
- `Sources/QuantumLoopMaker.swift` — deterministic 8K screen-saver renderer with synchronized seamless motion and explicit sRGB/Rec.709 metadata.
- `Sources/QuantumTerminalScreenSaver.swift` — native screen-saver source retained for reference.
- `Sources/Info.plist` and `Sources/ScreenSaver-Info.plist` — macOS metadata templates.

## Visual behavior

The desktop layer renders at 30 fps on normal power and 15 fps in Low Power Mode. It pauses while the display sleeps or the session becomes inactive, and resumes automatically. When a monitor is connected, disconnected, or changes resolution, the live layer rebuilds itself using the new display's Retina scale.

The screen-saver renderer uses integer-period motion terms so the final frame meets the first frame without a visible jump. The screen saver is intended to be used as the only active entry in an Aerial custom playlist.

## Build

Run on Apple Silicon macOS with Xcode Command Line Tools installed:

```sh
swiftc Sources/QuantumTerminalLive.swift \
  -o QuantumTerminalLive \
  -framework AppKit -framework QuartzCore -framework ImageIO

swiftc Sources/QuantumLoopMaker.swift \
  -o QuantumLoopMaker \
  -framework AVFoundation -framework AppKit \
  -framework CoreGraphics -framework CoreVideo
```

To regenerate the 30-second screen-saver movie:

```sh
./QuantumLoopMaker \
  Assets/quantum-terminal-live-wallpaper-8k.png \
  /tmp/Quantum-Terminal-Secure-Core.mov
```

## Installation notes

The active desktop deployment uses a small accessory app with one borderless window per display and a `RunAtLoad`/`KeepAlive` LaunchAgent. The Aerial screen saver uses the movie from its `My Videos` directory and a custom screen-playlist entry with a 30-second duration in loop mode.

Keep the PNG and MOV together when moving the project to another Mac. The large MOV is intentionally committed as a release asset in this private repository so the exact installed screen saver can be reproduced.

## Quality and privacy

The artwork contains no user data, credentials, telemetry, network endpoints, or external service configuration. The visual is intentionally local-only and contains no cloud, Copilot, or Matrix components.



## Security notes

- Keep this repository **private** unless it is intentionally public.
- Never commit `.env`, API keys, tokens, session cookies, private keys, or live evidence dumps.
- Prefer `.env.example` (or documented placeholders) for required configuration.
- Rotate any credential that may have been pasted into chat, tickets, or screenshots.
- Treat model / automation output as unverified until a human reviews it.



## Troubleshooting

| Symptom | What to try |
|---------|-------------|
| Local app / site will not start | Confirm runtime versions (Node/Python/macOS) match README requirements; delete stale `node_modules` / caches and reinstall from the lockfile. |
| Secrets / auth errors | Ensure ignored `.env*` (or Keychain / Secret Store) values are set; never commit real secrets to fix a local failure. |
| CI / checks failing | Run the same lint/test/validate command locally that CI runs; fix formatting and lockfile drift before pushing. |
| Path-not-found on a new machine | Replace machine-specific absolute paths with `$HOME` / relative paths, or copy the documented profile layout first. |
| Unexpected network calls | Prefer local / offline modes when documented; block outbound access if you are reviewing sensitive case material. |

## License

MIT — see [LICENSE](LICENSE).
