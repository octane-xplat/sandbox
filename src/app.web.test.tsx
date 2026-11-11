/** @jsxImportSource @octane-xplat/jsx/dom */
import { expect, it, vi } from 'vitest'
import { createRoot } from 'octane'
import { App } from './App.tsrx'
import { SHORT_TEXT, LONG_TEXT } from './samples'

it('updates every sizing case and resets the controls (no layout claims in jsdom)', async () => {
	const container = document.createElement('div')

	document.body.append(container)

	const root = createRoot(container)
	const target = (id: string) => container.querySelector<HTMLElement>(`[data-testid="fit.${id}"]`)!

	try {
		root.render(App)
		await vi.waitFor(() => expect(target('wrapped.text')?.textContent).toBe(SHORT_TEXT))
		target('long').click()
		await vi.waitFor(() => expect(target('wrapped.text').textContent).toBe(LONG_TEXT))
		expect(target('intrinsic.text').textContent).toBe(LONG_TEXT)
		expect(target('stretch.text').textContent).toBe(LONG_TEXT)
		target('width').click()
		target('padding').click()
		await vi.waitFor(() => expect(target('wrapped.parent').style.width).toBe('220px'))
		await vi.waitFor(() => expect(target('wrapped.box').style.padding).toBe('24px'))
		target('reset').click()
		await vi.waitFor(() => expect(target('wrapped.text').textContent).toBe(SHORT_TEXT))
		expect(target('wrapped.parent').style.width).toBe('300px')
		expect(target('wrapped.box').style.padding).toBe('12px')
	} finally {
		root.unmount()
		container.remove()
	}
})
