import { useEffect, useRef } from 'octane'
import { useSignal$ } from 'octane/signals/client'
import {
	View,
	HStack,
	Grid,
	Text,
	Pressable,
	VirtualList,
	SafeArea,
	type VirtualListHandle,
} from '@octane-xplat/ui'

import { regularRows, stressRows, type GridItem, type GridRow } from './grid-data'

export function App() {
	const stress$ = useSignal$(false)
	const selected$ = useSignal$(new Set<string>())
	const list = useRef<VirtualListHandle | null>(null)
	const rows = stress$.get() ? stressRows : regularRows
	const seekTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

	function cancelSeek() {
		if (seekTimer.current !== null) {
			clearTimeout(seekTimer.current)
		}

		seekTimer.current = null
	}

	useEffect(() => cancelSeek, [])

	function jumpToLast() {
		cancelSeek()

		const key = rows[rows.length - 1]!.id

		list.current?.scrollToItem(key, { align: 'end' })
		// Deep seeks start from estimated row heights. Repeat after destination
		// layout so the native scroll view can apply the measured content extent.
		seekTimer.current = setTimeout(() => {
			seekTimer.current = null
			list.current?.scrollToItem(key, { align: 'end' })
		}, 200)
	}

	function toggle(item: GridItem) {
		selected$.set((current) => {
			const next = new Set(current)

			if (next.has(item.id)) {
				next.delete(item.id)
			} else {
				next.add(item.id)
			}

			return next
		})
	}

	function card(item: GridItem, column: number) {
		return (
			<Pressable
				col={column}
				testID={`grid.item.${item.id}`}
				accessibilityLabel={`Sample ${item.number}, ${item.category}`}
				accessibilityState={{ selected: selected$.get().has(item.id) }}
				className={[
					'card',
					`tone-${item.category.toLowerCase()}`,
					selected$.get().has(item.id) && 'selected',
				]}
				onPress={() => toggle(item)}
			>
				<Text className="card-category">{item.category}</Text>
				<Text className="card-number">{String(item.number).padStart(5, '0')}</Text>
				<Text className="card-state">
					{selected$.get().has(item.id) ? 'Selected' : 'Tap to select'}
				</Text>
			</Pressable>
		)
	}

	function row(item: GridRow) {
		return (
			<View testID={`grid.row.${item.left.id}`} className="grid-row">
				<Grid className="grid-pair" columns="*,12,*" rows="*">
					{card(item.left, 0)}
					{item.right ? card(item.right, 2) : null}
				</Grid>
			</View>
		)
	}

	return (
		<SafeArea className="screen">
			<View className="app">
				<Text className="eyebrow">VIRTUALIZATION LAB / 01</Text>
				<Text className="title" accessibilityRole="heading">
					Two columns. Long scroll.
				</Text>
				<Text className="muted">
					A shared grid for web, iOS and Android. Only nearby rows stay mounted.
				</Text>
				<HStack className="toolbar">
					<Pressable
						testID="grid.first"
						accessibilityLabel="Jump to first row"
						className="button"
						onPress={() => {
							cancelSeek()
							list.current?.scrollToIndex(0)
						}}
					>
						<Text>First row</Text>
					</Pressable>
					<Pressable
						testID="grid.last"
						accessibilityLabel="Jump to last row"
						className="button"
						onPress={jumpToLast}
					>
						<Text>Last row</Text>
					</Pressable>
					<Pressable
						testID="grid.stress"
						accessibilityLabel="Toggle 10001 items"
						className="button"
						accessibilityState={{ pressed: stress$.get() }}
						onPress={() => {
							cancelSeek()
							list.current?.scrollToOffset(0)
							stress$.set((value) => !value)
						}}
					>
						<Text>{stress$.get() ? 'Use 1,001' : 'Use 10,001'}</Text>
					</Pressable>
				</HStack>
				<Text testID="grid.summary" className="summary">
					{stress$.get() ? '10,001 items · 5,001 rows' : '1,001 items · 501 rows'} · 2 columns
				</Text>
				<VirtualList
					testID="grid.viewport"
					className="grid-viewport"
					ref={list}
					items={rows}
					keyExtractor={(item) => item.id}
					getItemType={() => 'pair'}
					renderItem={row}
				/>
				<Text testID="grid.selection" className="selection" accessibilityLiveRegion="polite">
					{selected$.get().size} selected
				</Text>
				<Text className="muted">
					Selection stays with each item when its row leaves the window.
				</Text>
			</View>
		</SafeArea>
	)
}
