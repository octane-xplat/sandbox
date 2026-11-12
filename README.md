# Virtualized two-column grid

A focused Octane Xplat experiment for web, iOS and Android. The shared screen
uses `VirtualList` with stable, keyed pairs of cards. Only nearby pairs mount;
this is row virtualization, not a wrapping container holding the whole dataset.

- Starts with 1,001 cards (501 rows); switch to 10,001 cards (5,001 rows).
- First/last controls exercise deep seeks without manually scrolling thousands of cards.
  Last-row seeks repeat after 200 ms to settle against native measured layout;
  first-row seeks, dataset changes and unmounts cancel the pending correction.
- Tap cards to select them. Selection is keyed by item ID in the screen, so it
  survives row unmounts and dataset switches.
- Both columns use equal Grid star tracks with a fixed 12-unit gutter. The
  empty second track preserves the final odd card's width. Rows have a fixed
  144-unit extent including their bottom gap.
- The viewport is deliberately bounded to 360 logical units on every target.

```sh
pnpm install --frozen-lockfile # pnpm 11.24.0
pnpm dev
pnpm dev:ios --device 91D40099-A056-497D-A572-ADDDFD6A8F23
pnpm dev:android --device DEVICE_SERIAL
```

## Checks

```sh
pnpm lint
pnpm typecheck
pnpm test:web
pnpm build
pnpm test:ios --device 91D40099-A056-497D-A572-ADDDFD6A8F23
pnpm test:android --device DEVICE_SERIAL
```

Web tests use jsdom with a supplied viewport height. They check pairing, bounded
mounted content, deep seeks, the odd final row, dataset switching and selection
persistence. They do not establish browser layout or OS input behavior. The
native app spec exercises the real list hosts, selection and first/last seeks
through the managed test runner. Its taps dispatch native gesture observers;
they do not establish OS hit testing.

No visual analysis or screenshots are used for this experiment. Keep the
experiment branch separate from `main`.

For a physical iPhone, use the computer's reachable LAN address for the test
connection (both devices must be on the same network). Allow local network
access if iOS asks:

```sh
NS_TEST_HOST=0.0.0.0 VITE_NATIVE_TEST_URL=ws://COMPUTER_LAN_IP:17878 \
  pnpm test:ios --device IPHONE_UDID
```

The URL is supplied only to the test entry. No machine address is saved in source.
