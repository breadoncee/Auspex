# Changelog

All notable changes to Auspex are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/breadoncee/Auspex/compare/v1.0...HEAD
[1.0.0]: https://github.com/breadoncee/Auspex/releases/tag/v1.0
