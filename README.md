# Fit-to-text sizing experiment

A shared web/iOS/Android demo for content-sized containers. Uses the published
Octane Xplat 0.20.0 package set and Octane 0.16.3. No local framework link.

## Run and assess

1. Use pnpm 11.24.0 and run `pnpm install --frozen-lockfile`.
2. Run `pnpm dev` and open the printed URL.
3. Choose **Short text**, **Long text**, or **Unbroken word**, or edit **Sample text**.
4. Toggle the parent between 300/220 DIP and padding between 12/24 DIP.
5. Compare the five lanes and their live bounds; **Reset** restores the initial state.

The gray lane is the parent; green is the measured container; orange is stretch.
The uncapped single-line case deliberately permits overflow. It is a sizing
probe, not a production badge with truncation guarantees. All lanes update from
the same text, width and padding state. Stable IDs start with `fit.`.

## Supported shared API

Use a flex column parent, **auto width** (omit width), and
`alignSelf="flex-start"` on the child. The equivalent parent-wide setting is
`VStack hAlign="start"`. Set `alignSelf="stretch"` to compare filling the lane.
Author static layout through classes; the demo's inline width/padding values
are dynamic controls.

```tsx
<View className="lane">
  <View className="badge" alignSelf="flex-start">
    <Text>Hi</Text>
  </View>
</View>
```

```css
.lane { display: flex; flex-direction: column; width: 300px; }
.badge { display: flex; flex-direction: column; padding: 12px; }
```

Explicit `display:flex` matters: in the published web package, `View` supplies
`flex-direction` but does not itself establish flex layout. Native `View`
selects a flex Mason host. A block web parent otherwise ignores `alignSelf`
for width sizing. This demo authors the same flex layout on both targets.

- Intrinsic case: omit width limits and use `Text maxLines={1}`. This prop is a
  single-line **truncation** request; unconstrained browser measurements show
  natural width, but its native behavior must be measured separately.
- Constrained case: `min-width:0; max-width:100%`, unlimited text lines. Short
  text hugs; long text fills the available width and gains height by wrapping.
- Limits: `min-width:180px; max-width:240px` leaves extra room around short text
  and caps long text. The available parent width may constrain it further.
- Conflict: `min-width:260px; max-width:200px` probes min/max precedence. In
  Chromium the minimum wins, including overflowing a 220px parent.
- A capped wrapped box uses its available width; it does not run a second sizing
  pass to tighten around the longest resulting line. In Chromium, the 300px
  box has a 276px text host while its widest rendered line is about 262.3px.
- A maximum width does not guarantee unbroken words wrap. The browser token
  probe preserves one unbroken line that can overflow the text host.
- Numeric dimensions are DIPs on native, CSS pixels on web. Width limits use
  the outer box model, including padding. Content-sized height includes
  vertical padding too. Fonts/line metrics can differ across operating systems.

This uses ordinary supported shared flex/styles APIs, not a new sizing API or
CSS `width:fit-content`. Arbitrary CSS strings being accepted by a type does
not establish native support for that keyword.

`useMeasure()` attaches to `View.ref` and reports live bounds; `null` means
layout is pending. `Text` does not expose `ref` in the published public props,
so the demo's readout measures a zero-padding content wrapper. Automated
checks measure the actual text host separately. Host rectangles and DOM text
ranges are layout evidence, not glyph-ink or screenshot evidence.

References: [layout and component APIs](https://octane-xplat.goddardai.org/components),
[shared styling](https://octane-xplat.goddardai.org/styling), and
[framework source](https://github.com/octane-xplat/octane-xplat/tree/main/packages/ui).
The installed 0.20.0 declarations and versioned source were checked alongside
the live documentation.

## Repeatable checks

```sh
pnpm lint
pnpm typecheck
pnpm test:web
pnpm test:links
pnpm build
pnpm test:layout:web
```

`test:web` checks control state in jsdom and makes no layout claims.
`test:layout:web` starts Vite on 127.0.0.1:4183, launches an isolated headless
Google Chrome, exercises eight states at desktop/phone browser widths, and
asserts actual `getBoundingClientRect`/DOM Range measurements. No screenshots,
video, or tracing are recorded. It prints full measurements as JSON. Chrome
must already be installed; alternatively set `CHROMIUM_EXECUTABLE` to an
installed Chromium executable. Set `LAYOUT_OUTPUT=/absolute/path/results.json`
to save raw states. The script stops its server and browser on completion.

### Native checks on this shared host

The app has its own ID, `org.octanexplat.fittext`, and test port 17883 so other
experiments' apps and bridges can coexist. Native tests log `FIT_LAYOUT` JSON
from `getActualSize()` on parent, container and actual native label. They
exercise short/long/shrink/padding/narrow-parent/token states. Gesture dispatch
checks handler wiring, not OS touch hit-testing. Tests use the main thread;
no simulator clones or parallel device workers.

Compile tests before reserving a device:

```sh
goddard-agent resource run --json '{"resources":{"native_builds":1},"purpose":"Fit-to-text test build"}' -- pnpm build:ios --env.unitTesting
goddard-agent resource run --json '{"resources":{"native_builds":1},"purpose":"Fit-to-text test build"}' -- pnpm build:android --env.unitTesting
```

Then run one device phase at a time (no native compilation in this phase):

```sh
goddard-agent resource run --json '{"resources":{"exclusive":["ios:91D40099-A056-497D-A572-ADDDFD6A8F23"],"resident_devices":1},"purpose":"Fit-to-text iOS measurements"}' -- bash scripts/run-prebuilt-native.sh ios
goddard-agent resource run --json '{"resources":{"exclusive":["android:elegant-fir-probe"],"resident_devices":1},"purpose":"Fit-to-text Android measurements"}' -- bash scripts/run-prebuilt-native.sh android
```

The helper uses only the required existing device, installs the prebuilt test
app, and runs the maintained Vitest suite through the supported custom launch
command. It shuts down a virtual device only if it booted it, preserves an
already-running device, and stops only this experiment's app. It refuses a
second Android emulator. Missing/incompatible devices remain blockers.

For the interactive native demo, build without `--env.unitTesting`, then run
`pnpm dev:ios --device 91D40099-A056-497D-A572-ADDDFD6A8F23` or
`pnpm dev:android --device DEVICE_SERIAL` inside the corresponding combined
build/device resource reservation. Use the serial of `elegant-fir-probe` only.

Actual run results and platform limitations are recorded separately in the
experiment verification report; compilation alone does not verify layout.
