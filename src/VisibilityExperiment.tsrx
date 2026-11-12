import { useEffect } from 'octane'
import { useSignal$ } from 'octane/signals/client'
import { Grid, Screen, Text, View, Pressable } from '@octane-xplat/ui'
import { visibilityStyle } from './visibility-style'

import type { Visibility } from './visibility-types'

// All changes go through public props and compiler-owned @if blocks.
export function Samples(props: { prefix: string }) @{
	const mode$ = useSignal$<Visibility>('hidden')
	const mounted$ = useSignal$(false)
	const text$ = useSignal$('-10s')
	const wide$ = useSignal$(false)
	const ticks$ = useSignal$(0)
	const presses$ = useSignal$(0)

	useEffect(() => {
		const timer = setInterval(() => ticks$.set((n) => n + 1), 50)

		return () => clearInterval(timer)
	}, [])

	<View testID={props.prefix + '.samples'}>
		<Text testID={props.prefix + '.heartbeat'}>{ticks$.get()}</Text>
		<Pressable testID={props.prefix + '.input'} onPress={() => presses$.set((n) => n + 1)}>
			<Text>{'Input ' + presses$.get()}</Text>
		</Pressable>
		<Pressable
			testID={props.prefix + '.next'}
			onPress={() =>
				mode$.set((v) => (v === 'hidden' ? 'collapse' : v === 'collapse' ? 'visible' : 'hidden'))
			}
		>
			<Text>{'Visibility: ' + mode$.get()}</Text>
		</Pressable>
		<Pressable
			testID={props.prefix + '.text'}
			onPress={() => text$.set((v) => (v === '-10s' ? '+10s changed while hidden' : '-10s'))}
		>
			<Text>Change text</Text>
		</Pressable>
		<Pressable testID={props.prefix + '.mount'} onPress={() => mounted$.set((v) => !v)}>
			<Text>Mount / remove</Text>
		</Pressable>
		<Pressable testID={props.prefix + '.resize'} onPress={() => wide$.set((v) => !v)}>
			<Text>Resize</Text>
		</Pressable>
		<View testID={props.prefix + '.stage'} style={{ width: wide$.get() ? 260 : 180 }}>
			<Text testID={props.prefix + '.visible'} className="probe-label">
				Always visible
			</Text>
			<Text testID={props.prefix + '.initial-hidden'} className="probe-label probe-hidden">
				Initially hidden
			</Text>
			<Text testID={props.prefix + '.initial-collapse'} className="probe-label probe-collapse">
				Initially collapsed
			</Text>
			<View className="probe-row">
				<Text
					testID={props.prefix + '.inline'}
					className="probe-label"
					style={visibilityStyle(mode$.get())}
				>
					{text$.get()}
				</Text>
				<Text testID={props.prefix + '.inline-after'}>after inline</Text>
			</View>
			<View className="probe-row">
				<Text testID={props.prefix + '.class'} className={['probe-label', 'probe-' + mode$.get()]}>
					{text$.get()}
				</Text>
				<Text testID={props.prefix + '.class-after'}>after class</Text>
			</View>
			<View className="probe-row">
				@if (mounted$.get()) {
					<Text testID={props.prefix + '.conditional'} className="probe-label">
						{text$.get()}
					</Text>
				}
				<Text testID={props.prefix + '.conditional-after'}>after conditional</Text>
			</View>
		</View>
	</View>
}

export function SimpleSamples() @{
	<Samples prefix="simple" />
}

export function LayeredSamples() @{
	<Screen>
		<Grid rows="*" columns="*">
			<View row={0} col={0}>
				<Text>Library behind player</Text>
			</View>
			<View row={0} col={0} className="probe-player">
				<Screen>
					<Grid rows="auto,*" columns="*">
						<Text row={0}>Player seek feedback</Text>
						<View row={1}>
							<Samples prefix="layered" />
						</View>
					</Grid>
				</Screen>
			</View>
		</Grid>
	</Screen>
}

export function VisibilityExperiment() @{
	const layered$ = useSignal$(false)

	<Screen>
		<View className="probe-app">
			<Pressable testID="probe.layered" onPress={() => layered$.set((v) => !v)}>
				<Text>Switch simple / layered</Text>
			</Pressable>
			@if (layered$.get()) {
				<LayeredSamples />
			} @else {
				<Samples prefix="simple" />
			}
		</View>
	</Screen>
}
