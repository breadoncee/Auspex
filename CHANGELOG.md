# Changelog

All notable changes to Auspex are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2026-10-17

### Added
- Live disk-backed swap usage in the Memory overview tile and detailed Memory card, sampled with RAM readings using `vm.swapusage`.
- Clear zero-usage and unavailable states. Swap stays separate from the RAM percentage and resident memory total.

## [1.1.1] - 2026-10-16

### Fixed
- Restore the menu bar pulse logo in builds that package PNG resources outside an asset catalog. Load a native template image explicitly and draw a fallback pulse if the resource is unavailable.
- Sign complete Xcode app bundles before packaging, including their resources.
- Verify menu bar icon rendering in light and dark appearances, including missing resources and Retina sizing.

## [1.1.0] - 2026-10-16

### Changed
- Added a remembered appearance setting: Follow macOS (default), Light, or Dark, applied to the panel and Settings.
- Prominent temperature card directly below the overview, showing CPU/SoC average, hottest sensor, and expandable individual readings in °C.
- Rebuilt the panel around a CPU/memory overview, readable native surfaces, larger text, visible scrolling, and expandable core, storage and sensor details.
- Added accessible metric descriptions, Reduce Motion/Transparency support, and a manual refresh button.
- Clarified refresh/energy settings and surface login-item errors and approval state.
- Keep macOS 26 compatibility and verify runtime collection on macOS 27.0.1.

### Fixed
- Reserve panel height for metric readings so the content does not collapse to just the header and footer.
- Memory Used now equals its displayed app, wired and compressed components; reclaimable file cache is excluded from the resident app estimate.
- Network rates use 64-bit per-interface counters and monotonic time, preventing overflow and interface-change spikes. Totals describe observed traffic.
- Temperature rows use unique registry IDs. Private temperature symbols resolve at runtime, allowing a thermal-state fallback if an OS update removes them.
- Bounded sampling prevents queued refresh work. Slow collectors use elapsed-time cadences, idle polling only collects the menu bar metric, and sleep/wake resets rate baselines.
- Disk free-space queries fall back to ordinary capacity. Battery reads select the internal source and support nested macOS capacity data, restoring health readings.
- Initial CPU baselines and unavailable network readings no longer appear as real zero-percent or zero-traffic readings.

### Added
- `make local` builds a runnable app with Command Line Tools when full Xcode is unavailable.
- `make verify` runs collector and lifecycle regression checks.

## [1.0.0] - 2026-05-24

### Added
- Menu bar system monitor with a glassy Liquid Glass panel (macOS 26, Apple Silicon).
- **CPU** card: overall load ring, per-core bars (Performance/Efficiency labeled), and a load sparkline.
- **Memory** card: used / wired / compressed with live memory-pressure color (green → yellow → red).
- **Storage** card: per-volume usage including external drives; free space matches Finder.
- **Network** card: live up/down throughput with trend sparklines and session totals.
- **Battery** card: charge, charging state, health %, and cycle count.
- **Temperatures** card: on-die sensors via the private IOHID API, with a `ProcessInfo.thermalState` fallback.
- Custom app icon and menu bar pulse glyph.
- Animated numeric transitions and per-metric accent colors; tuned for light and dark mode.
- Settings: refresh interval, inline menu bar stat (CPU %, RAM %, or icon only), and open at login.
- Frugal polling: fast updates while open, a slow idle tick to keep the menu bar current, and full pause when the inline stat is hidden.
- All metrics read via built-in macOS APIs — zero third-party dependencies.

[Unreleased]: https://github.com/breadoncee/Auspex/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/breadoncee/Auspex/releases/tag/v1.2.0
[1.1.1]: https://github.com/breadoncee/Auspex/releases/tag/v1.1.1
[1.1.0]: https://github.com/breadoncee/Auspex/releases/tag/v1.1.0
[1.0.0]: https://github.com/breadoncee/Auspex/releases/tag/v1.0
