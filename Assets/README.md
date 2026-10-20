# Assets

These files are generated, not hand-edited:

| File | Description |
| --- | --- |
| `quantum-terminal-live-wallpaper-8k.png` | 7680 × 4800 static master rendered by `QuantumArtwork`. |
| `Quantum-Terminal-Live-30s.mov` | 7680 × 4800, 30 fps, HEVC `hvc1`, 30.0 s, 22 Mbps target, seamless loop. |
| `AppIcon.icns` | macOS app icon, ten variants from 16 × 16 to 512 × 512 @2x. |
| `AppIcon-1024.png` | 1024 × 1024 icon preview, generated from the same renderer. |

Regenerate the wallpaper and movie:

```sh
./scripts/make-assets.sh
```

Regenerate the icon:

```sh
./scripts/make-icon.sh
```

The movie is intentionally encoded at a modest bitrate so it stays below
GitHub's 100 MiB per-file limit. If you increase
`AVVideoAverageBitRateKey` in `Sources/QuantumLoopMaker.swift`, publish the
movie as a GitHub Release asset or use Git LFS instead of committing it.

The PNG is the input for both the live app and the loop maker. Keep it in this
folder; `scripts/build.sh` copies it — and the freshly rendered `AppIcon.icns` —
into the app bundle's Resources.
