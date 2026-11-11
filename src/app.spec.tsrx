// Starter spec — `pnpm test:ios` / `pnpm test:android` run in the real mobile runtime
// (same renderer, native views, and services your app uses).
//
// mountXplat() renders a component onto the test host page and unmounts it
// when the test finishes; tap()/enterText() dispatch through the same
// gesture observers as real touches — that proves your wiring, not OS
// hit-testing (device journeys like that belong to Maestro).
import { describe, expect, it } from 'vitest'
import { isIOS, type View as NativeView } from '@nativescript/core'
import { useEffect, useState, useSyncExternalStore } from 'octane'
import { Pressable, Text, TextInput, View } from '@octane-xplat/ui'
import {
  type TextInputView,
  enterText,
  findByTestId,
  mountXplat,
  nextRenderPass,
  tap,
  viewText,
  waitUntil,
} from '@octane-xplat/platform/testing'

import { App } from './App.tsrx'
import { assetUrl, explicitUrl, source } from './svg-fixture'

// Controlled input — typing flows up through onChange and back down as the
// rendered value, and parent writes reach the native field.
function NameForm() @{
  const [name, setName] = useState('')

  <View>
    <TextInput testID="greeting.name" value={name} onChange={setName} placeholder="Your name" />
    <Pressable testID="greeting.reset" onPress={() => setName('Bob')}>
      <Text>set bob</Text>
    </Pressable>
    <Text>{'greeting: ' + (name || 'stranger')}</Text>
  </View>
}

// Conditional mount — a subtree exists only while its state says so.
function Details() @{
  const [open, setOpen] = useState(false)

  <View>
    <Pressable testID="details.toggle" onPress={() => setOpen(!open)}>
      <Text>toggle</Text>
    </Pressable>
    @if (open) {
      <Text>detail: open</Text>
    }
  </View>
}

// Async states — loading first, then a settled value or an error. The
// cleanup flag keeps a late timer from writing into an unmounted tree.
function FetchLabel(props: { fail?: boolean }) @{
  const [state, setState] = useState('loading')

  useEffect(() => {
    let live = true
    const timer = setTimeout(() => {
      if (live) {
        setState(props.fail ? 'error' : 'ready')
      }
    }, 30)

    return () => {
      live = false
      clearTimeout(timer)
    }
  }, [])

  <Text>{'fetch: ' + state}</Text>
}

describe('SVG import app on device', () => {
  it('mounts, reacts to a tap, and unmounts cleanly', async () => {
    const { view, host, unmount } = await mountXplat(App)

    expect(viewText(view).some((text) => text.includes('default: string'))).toBe(true)

    const icon = view.getViewById<NativeView>('svg-tinted')

    expect(icon?.isLoaded, 'imported SVG host loads').toBe(true)
    expect(explicitUrl).toBe(assetUrl)
    expect(assetUrl.startsWith('data:image/svg+xml')).toBe(true)
    expect(source.startsWith('<svg')).toBe(true)

    const svgHost = icon as typeof icon & { src: string }

    expect(svgHost.src).toContain('stroke="currentColor"')
    expect(svgHost.src).toContain('color="#2563eb"')

    const image = view.getViewById('svg-image') as typeof icon & { src: string }

    expect(image?.isLoaded).toBe(true)
    expect(image.src).toContain('<svg')

    // Object presence only; do not inspect or capture rendered image pixels.
    const decoded = (host: unknown) => {
      const native = (host as { nativeViewProtected: { image?: unknown; _svg?: unknown } })
        .nativeViewProtected

      return !!(isIOS ? native.image : native._svg)
    }

    await waitUntil(() => decoded(icon) && decoded(image), {
      message: 'SVG native decoder did not produce objects',
    })

    await tap(findByTestId(view, 'svg.large')!)
    await waitUntil(() => viewText(view).some((text) => text.includes('size=80')))
    await tap(findByTestId(view, 'svg.color')!)
    await waitUntil(() => viewText(view).some((text) => text.includes('color=#be123c')))
    await waitUntil(() => svgHost.src.includes('color="#be123c"'))
    await waitUntil(() => Math.round(icon!.getActualSize().width) === 80)
    expect(svgHost.src).toContain('fill="#f59e0b"')
    expect(svgHost.src).toContain('stroke="#7c2d12"')
    console.log(
      'SVG_NATIVE',
      JSON.stringify({
        assetPrefix: assetUrl.slice(0, 40),
        size: icon!.getActualSize(),
        decodedIcon: decoded(icon),
        decodedImage: decoded(image),
        source: svgHost.src,
      }),
    )

    await tap(findByTestId(view, 'svg.small')!)
    await waitUntil(() => Math.round(icon!.getActualSize().width) === 24)
    await tap(findByTestId(view, 'svg.remount')!)
    await waitUntil(() => !view.getViewById('svg-image'))
    await tap(findByTestId(view, 'svg.remount')!)
    await waitUntil(() => !!view.getViewById('svg-image')?.isLoaded)

    await unmount()
    await nextRenderPass()
    expect(host.content).toBe(null)
  })

  it('round-trips a controlled TextInput', async () => {
    const { view } = await mountXplat(NameForm)
    const field = findByTestId<TextInputView>(view, 'greeting.name')

    expect(field?.isLoaded).toBe(true)

    await enterText(field!, 'Ada')
    await waitUntil(() => viewText(view).includes('greeting: Ada'), {
      message: 'onChange did not deliver the typed text',
    })

    await tap(findByTestId(view, 'greeting.reset')!)
    await waitUntil(() => field?.text === 'Bob', {
      message: 'parent write did not reach the native field',
    })
  })

  it('mounts and unmounts a conditional subtree', async () => {
    const { view } = await mountXplat(Details)

    expect(viewText(view).includes('detail: open')).toBe(false)

    await tap(findByTestId(view, 'details.toggle')!)
    await waitUntil(() => viewText(view).includes('detail: open'))

    await tap(findByTestId(view, 'details.toggle')!)
    await waitUntil(() => !viewText(view).includes('detail: open'))
  })

  it('settles async loading and error states', async () => {
    const ready = await mountXplat(FetchLabel)

    await waitUntil(() => viewText(ready.view).includes('fetch: ready'), {
      message: 'loading state never settled',
    })

    const failed = await mountXplat(FetchLabel, { fail: true })

    await waitUntil(() => viewText(failed.view).includes('fetch: error'), {
      message: 'error state never surfaced',
    })
  })
})

// Observable cleanup contracts: every effect subscribe must pair with a
// cleanup at unmount, delayed work must stop firing, and a re-mount must not
// leave the previous root subscribed.
let activeEffects = 0
let ticks = 0

function IntervalCounter() @{
  useEffect(() => {
    activeEffects += 1

    const timer = setInterval(() => {
      ticks += 1
    }, 15)

    return () => {
      activeEffects -= 1
      clearInterval(timer)
    }
  }, [])

  <Text>interval</Text>
}

const listeners = new Set<() => void>()

function StoreReader() @{
  const count = useSyncExternalStore(
    (callback) => {
      listeners.add(callback)
      return () => {
        listeners.delete(callback)
      }
    },
    () => listeners.size,
  )

  <Text>{'subs: ' + count}</Text>
}

describe('mount/unmount cleanup', () => {
  it('runs effect cleanups and stops delayed work at unmount', async () => {
    ticks = 0
    for (let i = 0; i < 3; i++) {
      const { unmount } = await mountXplat(IntervalCounter)

      expect(activeEffects, 'each mount subscribes exactly once').toBe(1)
      await unmount()
      expect(activeEffects, 'unmount runs the effect cleanup').toBe(0)
    }

    // The cleared interval must not fire after the last unmount.
    const settled = ticks

    await new Promise((resolve) => setTimeout(resolve, 60))
    expect(ticks, 'interval work continued after unmount').toBe(settled)
  })

  it('releases external-store subscriptions at unmount', async () => {
    for (let i = 0; i < 3; i++) {
      const { unmount } = await mountXplat(StoreReader)

      expect(listeners.size, 'each mount subscribes exactly once').toBe(1)
      await unmount()
      expect(listeners.size, 'unmount releases the subscription').toBe(0)
    }
  })

  it('re-mounting replaces the previous root instead of leaking it', async () => {
    await mountXplat(IntervalCounter)
    expect(activeEffects).toBe(1)
    // mountXplat drops the previous root — its cleanup must already have run.
    await mountXplat(IntervalCounter)
    expect(activeEffects, 'previous root stayed subscribed after re-mount').toBe(1)
  })

  it('finishes automatic cleanup before the next case', () => {
    expect(activeEffects).toBe(0)
    expect(listeners.size).toBe(0)
  })
})
