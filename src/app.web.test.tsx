/** @jsxImportSource @octane-xplat/jsx/dom */
import { expect, it, vi } from 'vitest'
import { createRoot } from 'octane'
import { App } from './App.tsrx'
import { makeItems, pairItems } from './grid-data'

it('pairs items in order, preserves identity, and handles an empty or odd dataset', () => {
	expect(pairItems([])).toEqual([])

	const items = makeItems(5)
	const rows = pairItems(items)

	expect(rows.map((row) => [row.left.number, row.right?.number])).toEqual([
		[1, 2],
		[3, 4],
		[5, undefined],
	])

	expect(rows[0]!.left).toBe(items[0])
	expect(new Set(rows.map((row) => row.id)).size).toBe(3)
})

it('windows two-card rows, seeks deeply, and retains selection across unmounts', async () => {
	// jsdom does not lay out CSS. Supply a bounded viewport; this checks document
	// windowing and interaction contracts, not browser layout or hit testing.
	const height = vi.spyOn(HTMLElement.prototype, 'clientHeight', 'get').mockReturnValue(360)
	const container = document.createElement('div')

	document.body.append(container)

	const root = createRoot(container)
	const target = (id: string) => container.querySelector<HTMLElement>(`[data-testid="${id}"]`)
	const cards = () => container.querySelectorAll('[data-testid^="grid.item."]')

	try {
		root.render(App)
		await vi.waitFor(() => expect(target('grid.item.sample-1')).not.toBeNull())
		expect(target('grid.item.sample-2')).not.toBeNull()
		expect(cards().length).toBeLessThan(100)
		expect(target('grid.item.sample-1001')).toBeNull()

		target('grid.item.sample-1')!.click()
		await vi.waitFor(() => expect(target('grid.selection')?.textContent).toContain('1 selected'))
		target('grid.last')!.click()
		await vi.waitFor(() => expect(target('grid.item.sample-1001')).not.toBeNull())
		expect(target('grid.item.sample-1')).toBeNull()
		expect(
			target('grid.row.sample-1001')?.querySelectorAll('[data-testid^="grid.item."]').length,
		).toBe(1)

		expect(cards().length).toBeLessThan(100)

		target('grid.first')!.click()
		await vi.waitFor(() => expect(target('grid.item.sample-1')?.textContent).toContain('Selected'))
		target('grid.item.sample-1')!.click()
		await vi.waitFor(() => expect(target('grid.selection')?.textContent).toContain('0 selected'))

		const viewport = target('grid.viewport')!

		viewport.scrollTop = 6000
		viewport.dispatchEvent(new Event('scroll'))
		await vi.waitFor(() => expect(target('grid.item.sample-1')).toBeNull())
		expect(cards().length).toBeGreaterThan(0)
		expect(cards().length).toBeLessThan(100)
		target('grid.first')!.click()
		await vi.waitFor(() => expect(target('grid.item.sample-1')).not.toBeNull())

		target('grid.stress')!.click()
		await vi.waitFor(() => expect(target('grid.summary')?.textContent).toContain('10,001 items'))
		target('grid.last')!.click()
		await vi.waitFor(() => expect(target('grid.item.sample-10001')).not.toBeNull())
		expect(cards().length).toBeLessThan(100)
		target('grid.stress')!.click()
		await vi.waitFor(() => expect(target('grid.item.sample-1')).not.toBeNull())
		expect(target('grid.summary')?.textContent).toContain('1,001 items')
	} finally {
		root.unmount()
		container.remove()
		height.mockRestore()
	}
})
