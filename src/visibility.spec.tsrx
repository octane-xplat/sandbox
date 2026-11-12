/** @jsxImportSource @octane-xplat/jsx */
import { expect, it } from 'vitest'
import { isIOS, type View as NativeView } from '@nativescript/core'
import {
	mountXplat,
	findByTestId,
	tap,
	waitUntil,
	viewText,
	type TextInputView,
} from '@octane-xplat/platform/testing'

import { BareText } from './BareText.mobile.tsrx'
import { SimpleSamples, LayeredSamples } from './VisibilityExperiment.tsrx'
import '@octane-xplat/ui/theme/tokens.css'
import './style.css'

function flags(node: NativeView) {
	const native = node.nativeViewProtected

	return {
		id: node.id,
		visibility: node.visibility,
		nativePresent: Boolean(native),
		nativeHidden: native?.hidden,
		alpha: native?.alpha,
		layerHidden: native?.layer?.hidden,
		layerOpacity: native?.layer?.opacity,
		androidVisibility: node.android?.getVisibility(),
		constructor: node.constructor.name,
	}
}

function drawingSuppressed(node: NativeView) {
	const native = node.nativeViewProtected

	return isIOS
		? Boolean(
				native?.hidden ||
				native?.alpha === 0 ||
				native?.layer?.hidden ||
				native?.layer?.opacity === 0,
			)
		: node.android?.getVisibility() !== 0
}

for (const layered of [false, true]) {
	it(`public Text visibility and declarative mounting: ${layered ? 'layered' : 'simple'}`, async () => {
		const prefix = layered ? 'layered' : 'simple'
		const { view } = await mountXplat(layered ? LayeredSamples : SimpleSamples)
		const node = (id: string) => findByTestId<TextInputView>(view, prefix + '.' + id)!
		const click = async (id: string) => {
			await tap(node(id))
			await new Promise((resolve) => setTimeout(resolve, 60))
		}

		const left = (id: string) =>
			node(id).getLocationRelativeTo(node(id).parent as NativeView)?.x ?? -999

		const drawingFailures: string[] = []
		const checkHidden = (id: string, expected: boolean) => {
			if (drawingSuppressed(node(id)) !== expected) {
				drawingFailures.push(id + ': expected suppression=' + expected)
			}
		}

		await waitUntil(() => node('inline-after').getActualSize().width > 0)
		console.log(
			'PUBLIC_INITIAL_FLAGS',
			JSON.stringify({
				layered,
				nodes: ['visible', 'initial-hidden', 'initial-collapse', 'inline', 'class'].map((id) => ({
					testID: prefix + '.' + id,
					...flags(node(id)),
				})),
			}),
		)

		expect(node('initial-hidden').visibility).toBe('hidden')
		checkHidden('initial-hidden', true)
		expect(node('initial-collapse').visibility).toBe('collapse')
		checkHidden('initial-collapse', true)
		expect(node('conditional')).toBeUndefined()
		expect(left('inline-after')).toBeCloseTo(80, 0)
		expect(left('class-after')).toBeCloseTo(80, 0)

		const retained = node('inline')

		await click('text')
		await waitUntil(() => node('inline').text.includes('changed while hidden'))
		for (let cycle = 0; cycle < 3; cycle++) {
			for (const mode of ['collapse', 'visible', 'hidden'] as const) {
				await click('next')
				await waitUntil(
					() => node('inline').visibility === mode && node('class').visibility === mode,
				)

				await waitUntil(() => Math.abs(left('inline-after') - (mode === 'collapse' ? 0 : 80)) < 1)
				expect(left('class-after')).toBeCloseTo(mode === 'collapse' ? 0 : 80, 0)
				checkHidden('inline', mode !== 'visible')
				checkHidden('class', mode !== 'visible')
				expect(node('inline')).toBe(retained)
				await click('resize')
				node('stage').requestLayout()
				await click('input')
				console.log(
					'PUBLIC_TRANSITION',
					JSON.stringify({
						layered,
						cycle,
						mode,
						inline: flags(node('inline')),
						class: flags(node('class')),
						siblingX: left('inline-after'),
						ticks: node('heartbeat').text,
					}),
				)
			}

			await click('mount')
			await waitUntil(() => Boolean(node('conditional')))
			expect(node('conditional').text).toContain('changed while hidden')
			expect(left('conditional-after')).toBeCloseTo(80, 0)

			const previous = node('conditional')

			await click('mount')
			await waitUntil(() => !node('conditional'))
			expect(left('conditional-after')).toBeCloseTo(0, 0)
			await click('mount')
			await waitUntil(() => Boolean(node('conditional')))
			expect(node('conditional')).not.toBe(previous)
			await click('mount')
		}

		expect(viewText(node('input'))).toContain('Input 9')
		expect(Number(node('heartbeat').text)).toBeGreaterThan(3)
		console.log(
			'VISIBILITY_NONVISUAL',
			JSON.stringify({
				layered,
				ticks: node('heartbeat').text,
				input: viewText(node('input')),
				drawingFailures,
			}),
		)

		expect(drawingFailures).toEqual([])
	}, 30000)
}

it('compares bare native labels at first mount', async () => {
	const { view } = await mountXplat(BareText)
	const nodes = [
		'bare-visible',
		'bare-inline-hidden',
		'bare-class-hidden',
		'bare-inline-collapse',
	].map((id) => view.getViewById<NativeView>(id)!)

	await waitUntil(() => nodes[0].isLoaded)
	console.log('BARE_INITIAL_FLAGS', JSON.stringify(nodes.map(flags)))
	for (const node of nodes) {
		expect(node.nativeViewProtected).toBeTruthy()
		expect(drawingSuppressed(node)).toBe(node.visibility !== 'visible')
	}
})
