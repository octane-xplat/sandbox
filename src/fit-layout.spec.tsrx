import { expect, it } from 'vitest'
import type { View } from '@nativescript/core'
import {
	findByTestId,
	mountXplat,
	tap,
	waitUntil,
	nextRenderPass,
} from '@octane-xplat/platform/testing'

import { App } from './App.tsrx'

it('measures real native fit, wrapping, limits, stretch and dynamic changes', async () => {
	const { view } = await mountXplat(App)
	const find = (id: string) => findByTestId<View>(view, `fit.${id}`)!
	const read = () =>
		Object.fromEntries(
			['intrinsic', 'wrapped', 'limited', 'conflict', 'stretch'].map((name) => [
				name,
				{
					parent: find(`${name}.parent`).getActualSize(),
					box: find(`${name}.box`).getActualSize(),
					text: find(`${name}.text`).getActualSize(),
				},
			]),
		)

	const settle = async () => {
		await nextRenderPass()
		await new Promise((resolve) => setTimeout(resolve, 150))
		await nextRenderPass()
	}

	const measure = async (label: string) => {
		await settle()

		const cases = read()

		console.log(`FIT_LAYOUT ${JSON.stringify({ label, cases })}`)
		return cases
	}

	await waitUntil(() => find('wrapped.box')?.getActualSize().width > 0, {
		message: 'no native layout',
	})

	const short = await measure('short, 300 parent, 12 padding')

	await tap(find('long'))

	const long = await measure('long, 300 parent, 12 padding')

	await tap(find('width'))

	const narrow = await measure('long, 220 parent, 12 padding')

	await tap(find('short'))

	const shrunk = await measure('short again, 220 parent, 12 padding')

	await tap(find('padding'))

	const padded = await measure('short, 220 parent, 24 padding')

	await tap(find('token'))
	await measure('unbroken token')

	const near = (value: number, expected: number) =>
		expect(Math.abs(value - expected)).toBeLessThan(2)

	near(short.wrapped.box.width, short.wrapped.text.width + 24)
	expect(short.wrapped.box.width).toBeLessThan(short.wrapped.parent.width)
	near(short.stretch.box.width, short.stretch.parent.width)
	near(short.limited.box.width, 180)
	near(short.conflict.box.width, 260)
	near(long.wrapped.box.width, 300)
	expect(long.wrapped.text.height).toBeGreaterThan(short.wrapped.text.height)
	near(long.limited.box.width, 240)
	near(narrow.wrapped.box.width, 220)
	expect(narrow.wrapped.text.height).toBeGreaterThan(long.wrapped.text.height)
	near(shrunk.wrapped.box.width, short.wrapped.box.width)
	near(padded.wrapped.box.width - shrunk.wrapped.box.width, 24)
})
