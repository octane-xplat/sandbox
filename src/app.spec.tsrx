// Starter spec — `pnpm test:ios` / `pnpm test:android` run in the real mobile runtime
// (same renderer, native views, and services your app uses).
//
// mountXplat() renders a component onto the test host page and unmounts it
// when the test finishes; tap()/enterText() dispatch through the same
// gesture observers as real touches — that proves your wiring, not OS
// hit-testing (device journeys like that belong to Maestro).
import { describe, expect, it } from 'vitest'
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

describe('starter app on device', () => {
  it('updates and clears inset shadow on the native Mason host', async () => {
    const { view, host, unmount } = await mountXplat(App)
    const preview = findByTestId(view, 'shadow.preview')!
    const control = findByTestId(view, 'shadow.control')!
    // Mason's helper reads the native-backed style, not merely the input prop.
    const paint = (target: any) => target._styleHelper.boxShadow as string

    await waitUntil(() => paint(preview).includes('inset'))
    expect(paint(preview)).toContain('6px 8px 14px 4px')
    expect(paint(control)).toBe('none')

    const initialSize = preview.getActualSize()

    console.log('SHADOW_NATIVE_INITIAL', paint(preview), initialSize, control.getActualSize())
    expect(initialSize.width).toBeGreaterThan(0)
    expect(initialSize.height).toBeGreaterThan(0)
    expect(initialSize.width).toBeCloseTo(control.getActualSize().width, 0)
    expect(initialSize.height).toBeCloseTo(control.getActualSize().height, 0)
    for (const name of ['x', 'y', 'blur', 'spread']) {
      await tap(findByTestId(view, 'shadow.' + name + '.plus')!)
      await nextRenderPass()
    }

    await waitUntil(() => paint(preview).includes('8px 10px 16px 6px'))
    await tap(findByTestId(view, 'shadow.color.00000080')!)
    await waitUntil(() => paint(preview).includes('#00000080'))
    for (const rounded of [true, false]) {
      for (const clipped of [false, true]) {
        await tap(findByTestId(view, 'shadow.reset')!)
        await nextRenderPass()
        if (!rounded) {
          await tap(findByTestId(view, 'shadow.rounded')!)
        }

        if (clipped) {
          await tap(findByTestId(view, 'shadow.clip')!)
        }

        await nextRenderPass()

        const helper = (preview as any)._styleHelper

        console.log(
          'SHADOW_NATIVE_SHAPE',
          rounded,
          clipped,
          helper.borderRadius,
          helper.overflow,
          paint(preview),
          preview.getActualSize(),
        )

        expect(paint(preview)).toContain('inset')
        expect(String(helper.borderRadius)).toContain(rounded ? '24' : '0')
        expect(helper.overflow).toBe(clipped ? 'hidden' : 'visible')
      }
    }

    await tap(findByTestId(view, 'shadow.toggle')!)
    await waitUntil(() => paint(preview) === 'none')
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
