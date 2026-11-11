/** @jsxImportSource @octane-xplat/jsx/dom */
import { expect, it, vi } from 'vitest'
import { createRoot } from 'octane'
import { App } from './App.tsrx'
import { assetUrl, explicitUrl, source } from './svg-fixture'

it('imports the actual fixture and drives both Icon and Image consumers', async () => {
	expect(typeof assetUrl).toBe('string')
	expect(assetUrl).toMatch(/^(data:image\/svg\+xml|.*compass\.svg)/)
	expect(explicitUrl).toBe(assetUrl)
	expect(source).toContain('viewBox="0 0 32 32"')

	const container = document.createElement('div')

	document.body.append(container)

	const root = createRoot(container)
	const click = (id: string) =>
		container.querySelector<HTMLElement>(`[data-testid="${id}"]`)!.click()

	try {
		root.render(App)
		await vi.waitFor(() => expect(container.querySelector('#svg-tinted circle')).not.toBeNull())

		const tinted = () => container.querySelector<SVGElement>('#svg-tinted')!

		expect(tinted().getAttribute('viewBox')).toBe('0 0 32 32')
		expect(tinted().querySelector('circle')!.getAttribute('stroke')).toBe('currentColor')
		expect(tinted().querySelector('path')!.getAttribute('fill')).toBe('currentColor')
		expect(tinted().querySelectorAll('circle')[1].getAttribute('fill')).toBe('#f59e0b')
		expect(container.querySelector('#svg-asset')!.getAttribute('src')).toBe(assetUrl)
		expect(container.querySelector('#svg-image')!.getAttribute('src')).toBe(assetUrl)
		expect(container.querySelector('#svg-unknown')).toBeNull()
		click('svg.large')
		await vi.waitFor(() => expect(tinted().getAttribute('width')).toBe('80'))
		expect((container.querySelector('#svg-image') as HTMLElement).style.width).toBe('80px')
		click('svg.color')
		await vi.waitFor(() => expect(tinted().style.color).toBe('rgb(190, 18, 60)'))
		expect(tinted().querySelectorAll('circle')[1].getAttribute('stroke')).toBe('#7c2d12')
		click('svg.failure')
		await vi.waitFor(() =>
			expect(container.querySelector('#svg-image')!.getAttribute('src')).toBe(
				'/__missing_compass.svg',
			),
		)

		click('svg.failure')
		await vi.waitFor(() =>
			expect(container.querySelector('#svg-image')!.getAttribute('src')).toBe(assetUrl),
		)

		click('svg.remount')
		await vi.waitFor(() => expect(container.querySelector('#svg-image')).toBeNull())
		click('svg.remount')
		await vi.waitFor(() => expect(container.querySelector('#svg-image')).not.toBeNull())
		click('svg.small')
		await vi.waitFor(() => expect(tinted().getAttribute('height')).toBe('24'))
	} finally {
		root.unmount()
		container.remove()
	}
})
