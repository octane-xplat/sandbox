export interface GridItem {
	id: string
	number: number
	category: string
}

export interface GridRow {
	id: string
	left: GridItem
	right?: GridItem
}

const categories = ['Coast', 'Forest', 'Desert', 'Alpine']

export function makeItems(count: number): GridItem[] {
	return Array.from({ length: count }, (_, index) => ({
		id: `sample-${index + 1}`,
		number: index + 1,
		category: categories[index % categories.length]!,
	}))
}

// VirtualList owns vertical windowing; each logical row owns two columns.
// The spare slot keeps an odd final card at the same width as every other card.
export function pairItems(items: readonly GridItem[]): GridRow[] {
	const rows: GridRow[] = []

	for (let index = 0; index < items.length; index += 2) {
		const left = items[index]!
		const right = items[index + 1]

		rows.push({ id: `${left.id}:${right?.id ?? 'empty'}`, left, right })
	}

	return rows
}

export const regularRows = pairItems(makeItems(1001))
export const stressRows = pairItems(makeItems(10001))
