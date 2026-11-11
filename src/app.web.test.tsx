/** @jsxImportSource @octane-xplat/jsx/dom */
import { expect, it, vi } from 'vitest'
import { createRoot } from 'octane'
import { App } from './App.tsrx'

it('compares inset against none and updates parameters, corners, clipping and reset', async () => {
	const container = document.createElement('div')

	document.body.append(container)

	const root = createRoot(container)
	const host = (id: string) => container.querySelector<HTMLElement>(`[data-testid="shadow.${id}"]`)!
	const click = async (id: string) => {
		host(id).click()
		await new Promise((resolve) => setTimeout(resolve, 20))
	}

	try {
		root.render(App)
		await vi.waitFor(() =>
			expect(host('preview')?.style.boxShadow).toBe('inset 6px 8px 14px 4px #334155'),
		)

		expect(host('control').style.boxShadow).toBe('none')
		for (const name of ['x', 'y', 'blur', 'spread']) {
			await click(name + '.plus')
		}

		expect(host('preview').style.boxShadow).toBe('inset 8px 10px 16px 6px #334155')
		await click('color.00000080')
		expect(host('preview').style.boxShadow).toContain('#00000080')
		await click('rounded')
		await click('clip')
		expect(host('preview').style.borderRadius).toBe('0px')
		expect(host('preview').style.overflow).toBe('hidden')
		expect(host('control').style.overflow).toBe('hidden')
		await click('toggle')
		expect(host('preview').style.boxShadow).toBe('none')
		await click('reset')
		expect(host('preview').style.boxShadow).toBe('inset 6px 8px 14px 4px #334155')
		expect(host('preview').style.borderRadius).toBe('24px')
		expect(host('preview').style.overflow).toBe('visible')
	} finally {
		root.unmount()
		container.remove()
	}
})
