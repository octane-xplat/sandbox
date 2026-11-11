# Custom SVG import experiment

This branch tests an authored local SVG through the published Octane Xplat
asset and media APIs. **Known iOS limitation:** the imported `currentColor`
markup does not tint in the tested 0.20.0 native SVGKit path. Native vector-layer
properties remain black before and after `Icon.color` changes; literal amber
and brown paints decode correctly. Web tinting passes. The failing iOS contract
is retained as an explicit expected-failure test in `src/tint.spec.tsrx`.
Tracked in [framework issue #237](https://github.com/octane-xplat/octane-xplat/issues/237).

No SVG loader plugin, remote artwork, or pasted inline
replacement is used. Fixture: `src/assets/compass.svg`.

## Minimal consumer

A default import is an asset URL **string**, not a component, path-data object,
or raw XML. No query suffix is needed:

```tsx
import compassUrl from './assets/compass.svg'
import { Image } from '@octane-xplat/ui'

export function Compass() {
  return <Image src={compassUrl} alt="Compass" className="compass" contentFit="contain" />
}
// CSS: .compass { width: 32px; height: 32px; }
```

For a registered icon, pass that same string as `src`:

```tsx
import compassUrl from './assets/compass.svg'
import { createIconRegistry, Icon } from '@octane-xplat/ui'

const icons = createIconRegistry()
icons.registerIcon('compass', { src: compassUrl })
export function Compass() {
  return <Icon name="compass" registry={icons} size={32} accessibilityLabel="Compass" />
}
```

`Icon.color` does not recolor the `src` representation. For tintable fill and
stroke on web (with the iOS limitation above), import the actual file as text and supply inner markup to the registry:

```tsx
import compassSvg from './assets/compass.svg?raw'
import { createIconRegistry, Icon } from '@octane-xplat/ui'

const icons = createIconRegistry()
// Our trusted fixture has one plain outer svg and a known 32×32 viewBox.
// This wrapper removal is fixture-specific, not a general SVG parser/sanitizer.
const markup = compassSvg.replace(/^<svg\b[^>]*>/, '').replace(/<\/svg>\s*$/, '')
icons.registerIcon('compass', { markup, viewBox: '0 0 32 32' })
export function Compass() {
  return <Icon name="compass" registry={icons} size={80} color="#be123c" />
}
```

`Icon.svg` expects a path's `d` data, so do not pass either import to it.
`?url` is supported and equivalent to the default here; `?raw` is needed only
when you want source text. No component-transform suffix is configured.
For this small fixture, Vite 8.3.6 produces a percent-encoded
`data:image/svg+xml,...` string on web dev, web production, and both native
bundles. Do not assume every larger asset will inline or every build config
will produce the same URL spelling. Existing `vite/client` types declare these
imports; no custom `*.svg` declaration was added.

## Try the demo

1. Run `pnpm install --frozen-lockfile` with pnpm **11.24.0**.
2. Run `pnpm exec vite --host 127.0.0.1 --port 5203 --strictPort`; open
   `http://127.0.0.1:5203`.
3. Use **24 px / 80 px**, then **Blue / rose**. The probe's ring stroke
   and needle fill use `currentColor` and change on web; they remain black on the
   tested iOS renderer. Its amber fill and brown stroke are fixed.
   The default-import Icon and Image demonstrate the asset source path.
4. Use **Missing / valid source**, then restore the source. Use **Unmount / mount
   image** to repeat loading. The status labels describe requested state, not
   successful decoding. Unknown registered names intentionally mount no icon.

Native `size` is in DIPs; web dimensions are CSS pixels. Run the same app with
`pnpm dev:ios --device 91D40099-A056-497D-A572-ADDDFD6A8F23` or
`pnpm dev:android --device <serial-of-elegant-fir-probe>` **inside the required
Goddard resource reservation**. Do not create another device. The shared native
app id is the starter id, so coordinate installations with other experiments.

## Repeat verification

- `pnpm lint`
- `pnpm typecheck`
- `pnpm test:web` — actual module imports, registry rendering, interactions,
  source switching and remounting in jsdom; no decoding/layout claims.
- `pnpm build` — production web bundle.
- With the dev server above running, `pnpm test:browser` — actual headless
  Chromium decoding, computed SVG styles, layout, error/load events and recovery.
  Install a matching browser with `pnpm exec playwright install chromium` if
  needed, or set `CHROMIUM_PATH` to an existing Chromium executable.
- For production, run `pnpm exec vite preview --port 5204 --strictPort`, then
  `SVG_DEMO_URL=http://localhost:5204 pnpm test:browser`.
- `pnpm test:ios --device 91D40099-A056-497D-A572-ADDDFD6A8F23` and
  `pnpm test:android --device <serial>` are the maintained device tests. Their
  updated SVG case checks imported source values, native decoder object presence,
  dimensions, tint source updates and remounting. Run with resource reservations;
  these commands build and launch the test host. Tests dispatch framework events,
  not OS touches. A build alone does not establish that these tests pass.

For the allowed Android AVD, the ownership-aware launcher reuses an existing
`elegant-fir-probe` instance, or boots and later stops only its own instance:

```sh
goddard-agent resource run --json '{"resources":{"native_builds":1,"resident_devices":1,"exclusive":["android:elegant-fir-probe"]},"purpose":"SVG Android tests"}' -- sh scripts/verify-svg-android.sh
```

The managed runner compiles and runs as one supervised phase. Its isolated host
bridge uses port 17883. Standalone app builds reserve `native_builds:1` only.

## Physical iOS testing

The runner needs a LAN-reachable coordinator URL on physical iOS. Keep the
phone and Mac on a network where the phone can reach the Mac. In a reservation
with `exclusive:["device:<UDID>"]` and `native_builds:1` (no resident device slot),
run the following, replacing the example IP and device identifier:

```sh
NS_TEST_HOST=192.168.1.10 VITE_NATIVE_TEST_URL=ws://192.168.1.10:17883 pnpm test:ios --device <UDID>
```

`NS_TEST_HOST` binds the host runner to that interface; `VITE_NATIVE_TEST_URL`
embeds the matching WebSocket URL in the test entry only. The iOS app declares
local network use for development testing. Allow Local Network access if iOS
asks. Both values are optional; existing simulator/Android defaults remain.
No machine address is saved in source or the lockfile.

After device tests, launch the interactive app through NativeScript:

```sh
pnpm dev:ios --device <UDID> --no-watch --no-hmr --justlaunch
```

Run that command inside the physical-device + native-build reservation above.
The tests mount App temporarily, then return to the Vitest runner. Installing a
fresh debug IPA alone can still open that runner: NativeScript's device-side
`Library/Application Support/LiveSync/app` files survive app updates and override
the packaged entry. The normal `ns run` command syncs the demo entry and restarts
the app. Do not erase the phone or delete its app data to switch screens.

The original physical iPhone run passed all 9 ordinary tests plus 1 expected failure.
The SVG case checks native decoder objects, dimensions, tint source changes and
remounting. It does not inspect pixels or establish native painted colors.

The browser verifier never takes screenshots or reads pixels. It checks the
image decoder's `naturalWidth`, DOM attributes, computed styles and element
rectangles. It confirms browser error→load recovery for a missing local source.
Neither `IconProps` nor `ImageProps` exposes a shared SVG `onLoad`/`onError`
callback, and native SVG ignores `placeholder`. This demo does not invent a
shared loading state API. Native missing-file error/recovery behavior requires
separate qualification; do not infer it from browser behavior.

Framework pins: `octane-xplat`, `@octane-xplat/ui`, `@octane-xplat/platform`,
`@octane-xplat/jsx` **0.20.0**; `octane` **0.16.3**;
`@nativescript-community/octane` **0.2.5**; NativeScript core **9.1.3**;
iOS runtime **9.1.0**, Android runtime **9.1.1**; Vite **8.3.6**.
Published packages are used; no local framework link or framework change.

API references: [Octane components](https://octane-xplat.goddardai.org/components),
[UI API](https://octane-xplat.goddardai.org/package-ui),
[Vite asset imports](https://vite.dev/guide/assets.html).
