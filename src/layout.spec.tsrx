import { expect, it } from 'vitest'
import { Screen, type View } from '@nativescript/core'
import type { Scroll } from '@octane-xplat/nativescript-mason-core'
import { VStack } from '@octane-xplat/ui'
import { findByTestId, mountXplat, waitUntil } from '@octane-xplat/platform/testing'
import { App } from './App.tsrx'

function DeviceViewport() {
  return <VStack width={Screen.mainScreen.widthDIPs} height={Screen.mainScreen.heightDIPs}>
    <App />
  </VStack>
}

it('keeps the SVG cards inside the device viewport and wraps their text', async () => {
  const { view } = await mountXplat(DeviceViewport)
  const root = view.getActualSize()
  const ids = ['svg-page', 'svg-scroll', 'svg-content', 'svg-card-tinted', 'svg-card-asset', 'svg-card-image', 'svg-description']
  const measured = ids.map((id) => {
    const host = view.getViewById<View>(id)!
    const size = host.getActualSize()
    const location = host.getLocationInWindow()
    return { id, ...size, ...location }
  })
  for (const id of ['svg.small', 'svg.large', 'svg.color', 'svg.failure', 'svg.remount']) {
    const host = findByTestId<View>(view, id)!
    measured.push({ id, ...host.getActualSize(), ...host.getLocationInWindow() })
  }
  console.log('SVG_LAYOUT', JSON.stringify({
    viewport: root,
    page: measured.find((box) => box.id === 'svg-page'),
    cards: measured.filter((box) => box.id.startsWith('svg-card')),
    description: measured.find((box) => box.id === 'svg-description'),
  }))
  const rootX = view.getLocationInWindow().x
  for (const box of measured) {
    expect(box.x, box.id + ' left edge').toBeGreaterThanOrEqual(rootX - 1)
    expect(box.x + box.width, box.id + ' right edge').toBeLessThanOrEqual(rootX + root.width + 1)
  }
  expect(measured.find((box) => box.id === 'svg-description')!.height).toBeGreaterThan(30)
  const scroll = view.getViewById<Scroll>('svg-scroll')!
  expect(scroll.getActualSize().height).toBeLessThanOrEqual(root.height)
  expect(scroll.scrollHeight).toBeGreaterThan(scroll.getActualSize().height)
  scroll.scrollTo({ top: 40, behavior: 'instant' })
  await waitUntil(() => scroll.scrollTop > 0, { message: 'vertical scroll must remain usable' })
  console.log('SVG_SCROLL', JSON.stringify({ viewport: scroll.getActualSize(), contentHeight: scroll.scrollHeight, offset: scroll.scrollTop }))
  scroll.scrollTo({ top: 0, behavior: 'instant' })
})
