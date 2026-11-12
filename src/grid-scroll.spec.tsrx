/** @jsxImportSource @octane-xplat/jsx */
import { expect, it } from 'vitest'
import { SafeArea, Text, View, VirtualList } from '@octane-xplat/ui'
import { findByTestId, mountXplat, waitUntil } from '@octane-xplat/platform/testing'
import type { View as NativeView } from '@nativescript/core'
import { regularRows } from './grid-data'
import { App } from './App.tsrx'
import './grid-scroll.spec.css'

interface ScrollViewport extends NativeView {
  readonly scrollTop: number
  scrollTo(options: { top: number; behavior: 'instant' }): void
}

const rowRenders = new Map<string, number>()

function ScrollFixture() {
  return <SafeArea className="screen"><View className="app"><VirtualList
    testID="scroll.viewport"
    className="scroll-render-probe"
    items={regularRows}
    keyExtractor={(item) => item.id}
    getItemType={() => 'pair'}
    renderItem={(item) => {
      rowRenders.set(item.id, (rowRenders.get(item.id) ?? 0) + 1)
      return <View className="grid-row" testID={`scroll.row.${item.left.number}`}>
        <Text>{item.left.number}</Text>
      </View>
    }}
  /></View></SafeArea>
}

it('keeps retained rows out of render work when the native scroll window moves', async () => {
  rowRenders.clear()
  const { view } = await mountXplat(ScrollFixture)
  const viewport = findByTestId<ScrollViewport>(view, 'scroll.viewport')!
  await waitUntil(() => viewport.getActualSize().width > 0 && viewport.getActualSize().height > 0)
  console.log('Grid render probe viewport: ' + JSON.stringify(viewport.getActualSize()))
  await waitUntil(() => !!findByTestId(view, 'scroll.row.5')?.isLoaded)
  await new Promise((resolve) => setTimeout(resolve, 500))
  const retained = findByTestId(view, 'scroll.row.3')!
  const before = rowRenders.get(regularRows[1]!.id) ?? 0
  const mounted = () => regularRows.slice(0, 32)
    .filter((item) => findByTestId(view, `scroll.row.${item.left.number}`)?.isLoaded)
    .map((item) => item.left.number)
  const initialRows = new Set(mounted())
  viewport.scrollTo({ top: 432, behavior: 'instant' })
  try {
    await waitUntil(() => mounted().some((number) => !initialRows.has(number)), {
      message: 'native scroll did not bring a new row into the window',
    })
  } finally {
    console.log('Grid render probe window: ' + JSON.stringify({ before: [...initialRows], after: mounted(), offset: viewport.scrollTop }))
  }
  await new Promise((resolve) => setTimeout(resolve, 200))
  const after = rowRenders.get(regularRows[1]!.id) ?? 0
  console.log('Grid retained row render work: ' + JSON.stringify({ before, after, offset: viewport.scrollTop }))
  expect(findByTestId(view, 'scroll.row.3')).toBe(retained)
  expect(after).toBe(before)
})

it('keeps native rows covering the viewport during gentle and sustained fast scrolling', async () => {
  const { view } = await mountXplat(App)
  const viewport = findByTestId<ScrollViewport>(view, 'grid.viewport')!
  const row = (index: number) => findByTestId(view, `grid.row.sample-${index * 2 + 1}`)
  await waitUntil(() => {
    const first = row(0)?.getLocationOnScreen()?.y
    const third = row(2)?.getLocationOnScreen()?.y
    return first !== undefined && third !== undefined && Math.abs(third - first - 288) < 1
  })

  const phases = []
  let offset = 0
  for (const speed of [144, 1440]) {
    const start = Date.now()
    const origin = offset
    let samples = 0
    let maxGap = 0
    let longestSampleInterval = 0
    let previous = start
    while (Date.now() - start < 3000) {
      const elapsed = Date.now() - start
      offset = origin + speed * elapsed / 1000
      viewport.scrollTo({ top: offset, behavior: 'instant' })
      await new Promise((resolve) => setTimeout(resolve, 16))
      const now = Date.now()
      longestSampleInterval = Math.max(longestSampleInterval, now - previous)
      previous = now
      const top = viewport.getLocationOnScreen().y
      const height = viewport.getActualSize().height
      const first = Math.max(0, Math.floor(viewport.scrollTop / 144) - 1)
      const boxes = []
      for (let index = first; index < first + 6; index++) {
        const target = row(index)
        if (target?.isLoaded) {
          const y = target.getLocationOnScreen().y - top
          boxes.push({ top: y, bottom: y + target.getActualSize().height })
        }
      }
      let covered = 0
      for (const box of boxes.sort((a, b) => a.top - b.top)) {
        if (box.bottom <= 0 || box.top >= height) continue
        maxGap = Math.max(maxGap, box.top - covered)
        covered = Math.max(covered, box.bottom)
      }
      maxGap = Math.max(maxGap, height - covered)
      samples++
    }
    phases.push({ speed, samples, maxGap, longestSampleInterval, finalOffset: viewport.scrollTop })
  }
  const evidence = JSON.stringify(phases)
  console.log('Grid sustained native geometry (not frame pacing): ' + evidence)
  for (const phase of phases) {
    expect(phase.samples, evidence).toBeGreaterThan(10)
    expect(phase.maxGap, evidence).toBeLessThan(2)
  }
  expect(viewport.scrollTop, evidence).toBeGreaterThan(4000)
})
