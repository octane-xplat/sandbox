import { expect, it } from 'vitest'
import { isIOS, type View } from '@nativescript/core'
import { findByTestId, mountXplat, tap, waitUntil } from '@octane-xplat/platform/testing'
import { App } from './App.tsrx'

// Read vector-layer color properties only. Never read pixels, render images,
// take screenshots, or inspect SVGKit's raster image representation.
function rgba(color: unknown): number[] | null {
  if (!color) {
    return null
  }
  const red = new interop.Reference<number>()
  const green = new interop.Reference<number>()
  const blue = new interop.Reference<number>()
  const alpha = new interop.Reference<number>()
  if (!UIColor.colorWithCGColor(color).getRedGreenBlueAlpha(red, green, blue, alpha)) {
    throw new Error('Cannot convert vector paint color to RGB')
  }
  return [red.value, green.value, blue.value, alpha.value]
}

type SVGHost = View & {
  src: string
  nativeViewProtected: { image: { layerWithIdentifier(id: string): CAShapeLayer } }
}

function paints(host: SVGHost) {
  const image = host.nativeViewProtected.image
  const ring = image.layerWithIdentifier('compass-ring')
  const needle = image.layerWithIdentifier('compass-needle')
  const center = image.layerWithIdentifier('compass-center')
  return {
    ringStroke: rgba(ring.strokeColor),
    needleFill: rgba(needle.fillColor),
    centerFill: rgba(center.fillColor),
    centerStroke: rgba(center.strokeColor),
  }
}

// Known failure in published UI 0.20.0 / its SVGKit backend. Keep the desired
// contract asserted so a renderer fix becomes an unexpected pass.
// https://github.com/octane-xplat/octane-xplat/issues/237
it.runIf(isIOS).fails('applies Icon.color to imported currentColor SVG vector paints', async () => {
  const { view } = await mountXplat(App)
  const icon = view.getViewById<View>('svg-tinted') as SVGHost
  await waitUntil(() => !!icon.nativeViewProtected.image)
  const before = paints(icon)
  await tap(findByTestId(view, 'svg.color')!)
  await waitUntil(() => icon.src.includes('color="#be123c"'))
  const after = paints(icon)
  console.log('SVG_VECTOR_PAINTS', JSON.stringify({ before, after }))
  expect(before.needleFill).not.toBeNull()
  expect(after.needleFill).not.toBeNull()
  expect(after.centerFill).toEqual(before.centerFill)
  expect(after.centerStroke).toEqual(before.centerStroke)
  const blue = [37 / 255, 99 / 255, 235 / 255, 1]
  const rose = [190 / 255, 18 / 255, 60 / 255, 1]
  for (let i = 0; i < 4; i++) {
    expect(before.needleFill![i], 'blue needle component ' + i).toBeCloseTo(blue[i], 3)
    expect(after.needleFill![i], 'rose needle component ' + i).toBeCloseTo(rose[i], 3)
    expect(after.ringStroke![i], 'rose ring component ' + i).toBeCloseTo(rose[i], 3)
  }
})
