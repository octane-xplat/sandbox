# Inner shadow experiment

A compact Octane Xplat demo of a shadow **inside** the container boundary.
The left sample always has no shadow. The right sample uses the actual inset
shadow property, with no gradient or other substitute:

```tsx
<View style={{ boxShadow: 'inset 6px 8px 14px 4px #334155' }} />
```

Syntax: `inset <x> <y> <blur> <spread> <color>`. Offset and spread may be
negative; blur is nonnegative. The controls use CSS px, mapped to logical native
units by Mason. `none` clears the shadow. Try opaque colors and the half-alpha
`#00000080` preset. Static styles stay in `src/style.css`; the changing shadow,
radius and overflow are inline styles.

The API is supported by the pinned Mason package's `Style.boxShadow` declaration
and its upstream [BoxShadowDemo](https://github.com/octane-xplat/nativescript-mason/blob/core-v1.0.0-beta.7/apps/demo-vue/app/plugin-demos/BoxShadowDemo.vue).
The shared `View` maps to `masonview` on iOS/Android. This matters: the generic
NativeScript shadow API and normal outer elevation are different paths.
The Xplat styling guide's blanket native `box-shadow` warning is less specific
than this version's Mason implementation. Do not generalize these findings to
other host controls, framework versions or targets.

## Try it

1. Use pnpm **11.24.0** and install the pinned published packages:

   ```sh
   pnpm install --frozen-lockfile
   pnpm dev
   ```

2. Compare the two surfaces. Change x/y offset, blur, signed spread and color.
   Toggle the right shadow off and on. Reset restores every setting.
3. Toggle radius 24/0 and clipping visible/hidden in all four combinations.
   The orange child extends beyond the bottom/right edge of each surface.
   Both samples receive the same radius and overflow settings. An inset shadow
   and descendant clipping are distinct effects; the child helps compare them.

Verification coverage: real Chromium computed styles/layout and Android native
property/layout checks passed. Both native builds passed. The iOS runtime check
could not start: the required shared simulator remained occupied throughout the
broker's 600-second wait.

No screenshots or visual analysis were performed. Computed styles, native
property readback, source code and successful builds do **not** prove rendered
shadow appearance or rounded clipping fidelity. Visually assess these yourself
before relying on appearance. See the task's verification report for actual
platform outcomes and blockers.

## Repeat verification

```sh
pnpm lint
pnpm typecheck
pnpm test:web
pnpm test:links
pnpm build
```

The maintained web test checks control wiring and authored DOM properties in
jsdom. For real Chromium computed styles and layout, run a local Vite server
with `pnpm exec vite --host 127.0.0.1 --port 5187`. In another terminal:

```sh
npm install --prefix /tmp/inner-shadow-browser --ignore-scripts --no-audit --no-fund playwright
PLAYWRIGHT_MODULE=/tmp/inner-shadow-browser/node_modules/playwright/index.mjs node scripts/verify-shadow.web.mjs
```

The script uses an isolated headless Chrome process and captures no images.
Set `CHROME_PATH` for another Chrome installation and `DEMO_URL` for another URL.
It checks matching dimensions, all radius/clipping combinations, alpha color,
negative values, zero blur, off/on and reset. An overflowing child's layout
bounds still extend outside an `overflow:hidden` parent; this does not prove
that the child's pixels escape clipping.

Native builds must use the host resource broker:

```sh
goddard-agent resource run --json '{"resources":{"native_builds":1},"purpose":"Inner shadow iOS build"}' -- pnpm build:ios
goddard-agent resource run --json '{"resources":{"native_builds":1},"purpose":"Inner shadow Android build"}' -- pnpm build:android
```

For native tests reserve the device too, since the maintained runner builds and
runs in one command. Reuse only iOS UDID
`91D40099-A056-497D-A572-ADDDFD6A8F23` or Android AVD `elegant-fir-probe`.
Wait if another task owns the device. Do not create devices or download runtimes.
For example, with that iOS simulator already booted under your reservation:

```sh
goddard-agent resource run --json '{"resources":{"native_builds":1,"exclusive":["ios:91D40099-A056-497D-A572-ADDDFD6A8F23"],"resident_devices":1},"purpose":"Inner shadow iOS tests"}' -- pnpm test:ios --device 91D40099-A056-497D-A572-ADDDFD6A8F23
```

For Android, reserve `android:elegant-fir-probe` plus `resident_devices:1` and
`native_builds:1`, boot/reuse that AVD inside the reservation, then run
`pnpm test:android --device <its-adb-serial>` without parallel device workers.
Shut down only devices you booted before releasing the reservation.
Native tests read Mason's native-backed `boxShadow`, corner and overflow state,
exercise the controls, and log measurements with `SHADOW_NATIVE_*` markers.
They dispatch gesture handlers; they do not prove OS hit testing or painted pixels.

## Pinned versions

- Octane Xplat CLI/UI/platform/JSX: **0.20.0**
- Octane: **0.16.3**; NativeScript renderer: **0.2.5**
- Mason: **1.0.0-beta.7**; NativeScript core: **9.1.3**
- NativeScript iOS: **9.1.0**; Android: **9.1.1**; CLI: **9.1.1**

All supplied patches and catalog pins are preserved. No local framework link,
framework modifications or new app dependencies are needed.
