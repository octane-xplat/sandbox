# Native grid frame timing

These commands capture native rendering data on physical Android and iOS devices.
They build optimized release apps with a launch-only workload enabled, preserve
raw traces, and write machine-readable results and a short Markdown report.
There is no FPS counter in the app and no screenshot collection.

## Run a comparison

1. Build once per platform. Use new output directories outside the checkout:

   ```sh
   pnpm profile:build:android --out ~/dev/reports/octane-xplat-sandbox/fps/android-build
   pnpm profile:build:ios --out ~/dev/reports/octane-xplat-sandbox/fps/ios-build
   ```

   Android uses the standard local development keystore at
   `~/.android/debug.keystore` to sign a release variant. This is for local testing,
   not distribution. The key must already exist. iOS needs working development
   signing. Neither command creates a simulator or emulator. Build logs,
   packaged apps, SHA-256 hashes, Git revision and dirty state are saved with
   `build.json`. Use clean commits for comparisons intended as stable baselines.

2. Obtain the official Perfetto trace processor if it is not already installed:

   ```sh
   curl --fail --location https://get.perfetto.dev/trace_processor -o /tmp/grid-trace-processor
   chmod +x /tmp/grid-trace-processor
   ```

   The official launcher downloads its platform binary on first use. Set
   `TRACE_PROCESSOR=/path/to/trace_processor` instead of passing the flag below
   if you already have one. Python 3.9+, pnpm, adb, Xcode command-line tools and
   Goddard's resource broker are the host prerequisites. No new app dependencies
   are required.

3. Leave the target phone unlocked, then record a scenario:

   ```sh
   pnpm profile:android --device ANDROID_SERIAL \
     --build-manifest ~/dev/reports/octane-xplat-sandbox/fps/android-build/build.json \
     --trace-processor /tmp/grid-trace-processor \
     --scenario scroll --dataset 1001 --iterations 3 \
     --out ~/dev/reports/octane-xplat-sandbox/fps/android-scroll-1001

   pnpm profile:ios --device IPHONE_UDID \
     --build-manifest ~/dev/reports/octane-xplat-sandbox/fps/ios-build/build.json \
     --scenario scroll --dataset 1001 --iterations 3 \
     --out ~/dev/reports/octane-xplat-sandbox/fps/ios-scroll-1001
   ```

   Repeat with `--dataset 10001` and, separately, `--scenario jump`. Use a new
   output directory for every invocation; existing output is never overwritten.
   Each command reserves only its build or physical-device phase, installs the
   exact hashed artifact, and records three runs by default. Android requires
   API 31+ and rejects a debuggable app. iOS requires the phone to appear online
   in `xcrun xctrace list devices`; being reachable through devicectl alone is
   insufficient. No simulator is substituted if the phone is unavailable.

4. Read `report.md` and `summary.json` in each output directory. Keep the raw
   `.pftrace` or `.trace` alongside the result so timing spikes can be investigated.
   Compare matching platform, device, dataset, scenario and profiling settings.
   Keep device temperature, power mode and refresh-rate settings consistent.
   Do not interact with the app while a run is recording.

## Workloads and measurement windows

The profiling build accepts a launch request such as `scroll:10001`. Normal
launches remain interactive. Only builds made with `VITE_GRID_PROFILING=1`
accept requests; profiling is disabled in normal builds.

- `scroll`: after a three-second layout warmup, perform twelve native smooth
  scroll bursts at 1,200 ms intervals. Offsets go from 576 to 3,456 logical units
  in 576-unit increments, then return to zero. The measured window is 14.4 s.
- `jump`: after the same warmup, alternate last/first jumps six times at 1,000 ms
  intervals. The measured window is 6 s and includes the last-row correction.

Both scenarios use the same workload definition on both platforms, with either
1,001 or 10,001 items. They exercise programmatic native scrolling; gesture
handling, fling physics and uninterrupted finger-driven scrolling are separate
workloads. Native animation duration is controlled by the platform, so these
are reproducible workloads within a platform, not identical animations across OSes.

`GridProfile` is an Android async trace section or an iOS signpost interval.
Only app frames entirely inside that interval are summarized. Startup, warmup
and trailing idle time are excluded. Each capture lasts 26 s to include the
full interval. Missing markers, missing frame data, trace data loss, unexpected
schema or a mismatched build hash fail the run. A failed result preserves its
artifacts and reports `status: failed`, not zero jank.

## What the numbers mean

| Platform | Primary measurements | Interpretation |
| --- | --- | --- |
| Android | Janky-frame %, dropped-frame %, p50/p95/p99/max app frame production time and deadline overrun | Perfetto FrameTimeline identifies jank and presentation state using native frame deadlines. Production duration includes GPU work; it is not CPU-only time or display cadence. App frame tokens are deduplicated across layers. |
| iOS | Hitch count, hitch ms per second, hitch duration, frame pipeline lifetime percentiles | Instruments Animation Hitches supplies native hitch intervals. Pipeline lifetime is not the time between screen refreshes. No dropped-frame percentage is inferred from these tables. |

A janky frame and a dropped frame are different native classifications. They are
reported separately on Android. JSON also includes the app-deadline-missed rate
and native jank-type counts: overall jank can include compositor delays, buffer
stuffing and prediction errors, not only app rendering stalls. One frame may
have multiple jank flags. iOS/Android duration fields measure different
parts of their pipelines and must not be compared as interchangeable scores.
The summary includes per-run values and median jank/drop/hitch rates where
available. Percentiles use the nearest-rank convention.

No overall FPS is calculated from the entire window: intentional idle gaps and
adaptive refresh rates would make that misleading. No fixed 16.7 ms threshold
is used. Keep the raw trace for diagnosis, and use tail timings and native jank
or hitch rates to judge changes. Profiling overhead is present in both runs;
use the same capture settings when comparing revisions.

## Reanalyzing and extending

Each Android run saves the native trace, trace config, window query, app-frame
CSV/SQL and result. Each iOS run saves the native trace, table of contents and
frame/hitch/signpost XML. `profile_grid.py` keeps collection separate from pure
analysis functions, tested with `pnpm test:profiling`; workload scheduling is
covered by `pnpm test:web`.

Instruments export schemas vary by Xcode release. The current reader requires
`hitches`, `hitches-frame-lifetimes` and a signpost interval with raw nanosecond
start/duration cells and a process identity. Unknown fields fail explicitly;
inspect the saved XML and extend the reader with a regression fixture rather
than substituting zeroes or parsing rounded display text.

For future Android CI regression budgets, wrap real UI journeys in
Macrobenchmark `FrameTimingMetric`. This experiment's Perfetto runner establishes
capture and reporting without adding a separate Gradle benchmark project.

References: [Perfetto FrameTimeline](https://perfetto.dev/docs/data-sources/frametimeline),
[Android frame timing metrics](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-metrics),
[Apple Animation Hitches](https://developer.apple.com/documentation/xcode/improving-app-responsiveness).
