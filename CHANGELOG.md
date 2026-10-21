# Changelog

All notable changes to Quantum Terminal Live are documented here.
The project is procedural (no stock artwork), local-only (no network), and
ships a seamless 30-second 8K loop.

## [2.9.0] — 2026-10-20
### Added
- Core pulse rings: expanding violet sonar rings from the core on each pulse beat.
- Lens flare: a horizontal violet glare streaming through the core with a bright hot spot.
- Wall tracers: faint diagonal packet streaks crossing the service aisles.
- Chromatic-aberration RGB split on the full-frame CRT glitch.

## [2.8.0] — 2026-10-20
### Added
- Near-field bokeh discs that pulse with activity-driven intensity (more dramatic when you're active).
- Volumetric light sweep, far echo radar, memory-dump strip, process table, full-frame glitch, activity-reactive rain, boot fade-in, graceful fallback, golden snapshot test, and intensity control.

## [2.7.0] — 2026-10-20
### Added
- Volumetric light sweep (one revolution per loop) and a far "echo" radar ring for another depth plane.
- Recessed memory-dump strip (`MEMDUMP 0x7F3A`) with continuously counting bytes.
- `PROC // SENTRY` process table under the threat telemetry.
- Brief full-frame CRT glitch every 15 s.
- Activity-reactive digital rain: the rain brightens and speeds up right after input, then settles.
- One-time boot fade-in on first launch.
- Graceful fallback: a missing master no longer crashes — the desktop shows a solid dark-green void.

### Changed
- Light sweep drawn as a single flat wedge to stay within the CPU budget.

## [2.6.0] — 2026-10-20
### Added
- Near-field bokeh and twinkling motes for a foreground depth plane.
- Neon intensity chooser (Vivid / Standard / Dim) in the menu bar.

## [2.5.0] — 2026-10-20
### Changed
- Palette shifted to pure Matrix green (`#00FF40`), violet replaced with mint, across both the scene and the 8K master.
- Digital rain split into two parallax layers (22 far + 6 near columns); depth rays batched into one path.

## [2.4.0] — 2026-10-20
### Added
- Infinite Matrix depth: receding light corridor, full-screen digital rain, parallax dust, radiating rays.

## [2.3.0] — 2026-10-20
### Added
- Menu-bar status item (pause/resume, idle dim, open Aerial, reveal, quit).
- Idle auto-dim (45% after 5 min), occlusion/battery/Low-Power throttling.
- Telemetry uptime row and vault-seal progress bar.

## [2.2.0 – 2.2.2] — 2026-10-20
### Added
- Hacker terminal styling: sentinel console, trace-route panel, code rain, packet ticker, DEFCON badge, intrusion alert, CRT scanlines.
### Fixed
- Live-app CPU regression (100% → ~40%) via a static-master layer, a ~3.3 MP geometry overlay, and a full-Retina text overlay.

## [2.0.0 – 2.1.0] — 2026-10-20
### Added
- Initial procedural 8K master (radar vault, horizon, pylons, data walls) and the seamless 30-second HEVC loop.
