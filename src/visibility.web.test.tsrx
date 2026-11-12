/** @jsxImportSource @octane-xplat/jsx/dom */
import { expect, it, vi } from 'vitest'
import { createRoot } from 'octane'
import { SimpleSamples, LayeredSamples } from './VisibilityExperiment.tsrx'
import styles from './style.css?inline'
import webStyles from './visibility.web.css?inline'

for (const layered of [false, true]) {
	it(`public declarative visibility, removal and timers: ${layered ? 'layered' : 'simple'}`, async () => {
		const host = document.createElement('div')

		document.body.append(host)

		const sheet = document.createElement('style')

		sheet.textContent = styles + webStyles
		document.head.append(sheet)

		const root = createRoot(host)
		const prefix = layered ? 'layered' : 'simple'
		const node = (id: string) => host.querySelector<HTMLElement>(`[data-testid="${prefix}.${id}"]`)
		const click = async (id: string) => {
			node(id)!.click()
			await new Promise((resolve) => setTimeout(resolve, 30))
		}

		try {
			root.render(layered ? LayeredSamples : SimpleSamples)
			await vi.waitFor(() => expect(node('inline')).toBeTruthy())
			expect(node('initial-hidden')!.classList.contains('probe-hidden')).toBe(true)
			expect(node('initial-collapse')!.classList.contains('probe-collapse')).toBe(true)
			expect(node('conditional')).toBeNull()

			const retained = node('inline')

			await click('text')
			await vi.waitFor(() => expect(node('inline')!.textContent).toContain('changed while hidden'))
			for (let cycle = 0; cycle < 3; cycle++) {
				for (const mode of ['collapse', 'visible', 'hidden']) {
					await click('next')
					await vi.waitFor(() => {
						expect(node('next')!.textContent).toContain(mode)
						expect(node('class')!.classList.contains('probe-' + mode)).toBe(true)
						for (const id of ['inline']) {
							const style = getComputedStyle(node(id)!)

							expect(style.visibility).toBe(mode === 'hidden' ? 'hidden' : 'visible')
							expect(style.display === 'none').toBe(mode === 'collapse')
						}
					})

					expect(node('inline')).toBe(retained)
					await click('resize')
					await click('input')
				}

				await click('mount')
				await vi.waitFor(() =>
					expect(node('conditional')!.textContent).toContain('changed while hidden'),
				)

				const previous = node('conditional')

				await click('mount')
				await vi.waitFor(() => expect(node('conditional')).toBeNull())
				await click('mount')
				await vi.waitFor(() => expect(node('conditional')).not.toBe(previous))
				await click('mount')
			}

			expect(node('input')!.textContent).toBe('Input 9')
			expect(Number(node('heartbeat')!.textContent)).toBeGreaterThan(3)
		} finally {
			root.unmount()
			host.remove()
			sheet.remove()
		}
	})
}
