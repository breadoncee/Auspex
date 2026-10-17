# Monitoring performance check — 2026-10-17

The development benchmark exercises the real `SystemMonitor`, collectors, lifecycle and in-memory history. It creates an `NSApplication` with activation prohibited, starts the real application run loop, and lets the monitor's own timers run. It opens no window or menu-bar item, changes no existing Auspex preferences, and removes its separate random preferences domain after a normal run.

## Reproduce

```sh
Tools/benchmark.sh --mode cpu --duration 60
Tools/benchmark.sh --mode memory --duration 60
Tools/benchmark.sh --mode temperature --duration 60
Tools/benchmark.sh --mode icon --duration 60
Tools/benchmark.sh --mode open --duration 60 --interval 1
```

Modes `icon`, `cpu`, `memory` and `temperature` represent a closed panel with the indicated menu-bar setting. `open` calls the real `startActive()` lifecycle method, so all normal panel collectors and histories run, without rendering the panel. Duration defaults to 60 seconds; requested panel interval defaults to one second and supports 0.5–5 seconds. The closed panel uses the monitor's own slower idle cadence. Icon-only mode has no recurring monitor timer. One initial full collection still occurs in every mode.

The script uses an explicitly provided `DEVELOPER_DIR` or selects the installed full Xcode when available. It compiles optimized code, then prints one JSON result. Compilation is outside the measured interval. Subsequent measurements may use the already compiled `build/verification/benchmark` binary with the same arguments; rebuild after source changes.

## What is measured

- Elapsed time uses `ProcessInfo.systemUptime`, independent of wall-clock adjustments.
- Process user and system CPU time come from `getrusage(RUSAGE_SELF)`. CPU percentage is their sum divided by elapsed time, multiplied by 100: **100% means one fully occupied core**, rather than the entire computer.
- Darwin's `ru_maxrss` is peak resident memory **in bytes**; the report also converts it to MiB using 1,048,576 bytes per MiB. This is a process lifetime peak, not average or incremental memory.
- Per-metric completed attempts and successful readings come from changes to the monitor's real reading timestamps, observed when a sample finishes. Initial CPU/network baselines count as attempts and do not count as successful rates. These are **not OS wakeup counts**.
- Observation adds one small callback after a completed sample. The harness has one deadline timer and no polling timer. Rendering, layout, settings, updates and the installed application's other work are excluded. CPU measurement includes monitor initialization and its first collection; it starts after `NSApplication` setup.

## Short validation results

Measurements below are a single 20-second run per mode on this 11-logical-core Mac, with Low Power Mode off and the public thermal state nominal. Other development work was running concurrently. They validate scheduling and establish a provisional collection-process footprint.

| Mode | Elapsed | Process CPU time | CPU, one-core basis | Peak resident memory | Completed monitor samples |
| --- | ---: | ---: | ---: | ---: | ---: |
| Icon only | 20.008 s | 0.057295 s | 0.286% | 36.28 MiB | 1 |
| CPU menu | 20.005 s | 0.052670 s | 0.263% | 36.30 MiB | 7 |
| Open panel collection | 20.007 s | 0.129633 s | 0.648% | 36.30 MiB | 21 |

| Mode | CPU attempts | Memory | Network | Storage | Temperature | Battery |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Icon only | 1 | 1 | 1 | 1 | 1 | 1 |
| CPU menu | 7 | 1 | 1 | 1 | 1 | 1 |
| Open panel collection | 21 | 21 | 21 | 3 | 7 | 5 |

CPU/network success counts were zero for the icon run's first baselines; the CPU-menu run produced six valid CPU rates, and the open run produced 20 valid CPU and network rates. The observed attempt counts match the intended recurring schedules. The small CPU-time ordering between the icon and CPU modes illustrates why a single short run is insufficient to compare energy efficiency.

All three modes make one initial full collection. Icon-only mode should stop there. CPU-menu mode should subsequently collect CPU only, about every three seconds. Open mode should collect CPU/memory/network at the requested cadence, with slower disk, battery and temperature intervals. Count differences at exact timer boundaries and startup coalescing are expected.

## Limits and follow-up

These short measurements do not establish battery-life improvement or an energy budget. There is no before/after controlled baseline, ten-minute steady-state run, direct power measurement, full UI rendering cost, or OS wakeup count. The history buffers have not filled their full five-minute retention window. Concurrent builds and the existing installed Auspex can affect results. Peak RSS includes the benchmark's own framework and observation overhead.

Before claiming an efficiency improvement, repeat longer runs for all five modes on a quiet machine with comparable thermal and power conditions. Record actual application CPU, memory and wakeups with Instruments or Activity Monitor, include panel rendering, test Low Power Mode and sleep/wake, and compare equivalent signed release builds. Do not infer energy saved from collector-attempt counts alone.
