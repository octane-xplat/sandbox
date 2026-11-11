import { useState } from 'octane'
import { View, HStack, Text, Pressable, ScrollableArea, SafeArea } from '@octane-xplat/ui'

function Stepper(props: {
	name: string
	value: number
	min: number
	max: number
	change: (value: number) => void
}) {
	return (
		<HStack className="control">
			<Text className="control-label">
				{props.name}: {props.value}
			</Text>
			<Pressable
				className="btn"
				testID={'shadow.' + props.name + '.minus'}
				accessibilityLabel={'Decrease ' + props.name}
				onPress={() => props.change(Math.max(props.min, props.value - 2))}
			>
				<Text>−</Text>
			</Pressable>
			<Pressable
				className="btn"
				testID={'shadow.' + props.name + '.plus'}
				accessibilityLabel={'Increase ' + props.name}
				onPress={() => props.change(Math.min(props.max, props.value + 2))}
			>
				<Text>+</Text>
			</Pressable>
		</HStack>
	)
}

export function App() {
	const [enabled, setEnabled] = useState(true)
	const [x, setX] = useState(6)
	const [y, setY] = useState(8)
	const [blur, setBlur] = useState(14)
	const [spread, setSpread] = useState(4)
	const [rounded, setRounded] = useState(true)
	const [clipped, setClipped] = useState(false)
	const [color, setColor] = useState('#334155')
	const shadow = `inset ${x}px ${y}px ${blur}px ${spread}px ${color}`
	const shape = {
		borderRadius: rounded ? 24 : 0,
		overflow: clipped ? 'hidden' : 'visible',
	} as const

	return (
		<SafeArea>
			<ScrollableArea>
				<View className="app">
					<Text className="title">Inner shadow lab</Text>
					<Text>
						Inset shadow inside the boundary. Same size, fill and content in both samples.
					</Text>
					<Text className="notice">
						Property evidence only. Rendered appearance has not been visually verified on any
						target.
					</Text>
					<HStack className="comparison">
						<View className="sample-column">
							<Text>Control · off</Text>
							<View
								testID="shadow.control"
								className="sample"
								style={{ ...shape, boxShadow: 'none' }}
							>
								<Text>Surface</Text>
								<View className="overflow-marker">
									<Text>child</Text>
								</View>
							</View>
						</View>
						<View className="sample-column">
							<Text>{enabled ? 'Inset · on' : 'Inset · off'}</Text>
							<View
								testID="shadow.preview"
								className="sample"
								style={{ ...shape, boxShadow: enabled ? shadow : 'none' }}
							>
								<Text>Surface</Text>
								<View className="overflow-marker">
									<Text>child</Text>
								</View>
							</View>
						</View>
					</HStack>
					<Text testID="shadow.syntax">{enabled ? shadow : 'none'}</Text>
					<Text>
						Offsets −20…20; blur 0…40; spread −12…16. Values in CSS px / native logical units.
					</Text>
					<Stepper name="x" value={x} min={-20} max={20} change={setX} />
					<Stepper name="y" value={y} min={-20} max={20} change={setY} />
					<Stepper name="blur" value={blur} min={0} max={40} change={setBlur} />
					<Stepper name="spread" value={spread} min={-12} max={16} change={setSpread} />
					<HStack className="actions">
						{['#334155', '#be123c', '#0369a1', '#00000080'].map((choice) => (
							<Pressable
								className="btn"
								testID={'shadow.color.' + choice.slice(1)}
								accessibilityLabel={'Shadow color ' + choice}
								onPress={() => setColor(choice)}
							>
								<Text>{choice}</Text>
							</Pressable>
						))}
					</HStack>
					<HStack className="actions">
						<Pressable className="btn" testID="shadow.toggle" onPress={() => setEnabled(!enabled)}>
							<Text>{enabled ? 'Turn shadow off' : 'Turn shadow on'}</Text>
						</Pressable>
						<Pressable className="btn" testID="shadow.rounded" onPress={() => setRounded(!rounded)}>
							<Text>{rounded ? 'Radius: 24' : 'Radius: 0'}</Text>
						</Pressable>
						<Pressable className="btn" testID="shadow.clip" onPress={() => setClipped(!clipped)}>
							<Text>{clipped ? 'Clip: hidden' : 'Clip: visible'}</Text>
						</Pressable>
						<Pressable
							className="btn"
							testID="shadow.reset"
							onPress={() => {
								setEnabled(true)
								setX(6)
								setY(8)
								setBlur(14)
								setSpread(4)
								setRounded(true)
								setClipped(false)
								setColor('#334155')
							}}
						>
							<Text>Reset</Text>
						</Pressable>
					</HStack>
					<Text>
						The orange child extends beyond each surface. Toggle clipping and square/rounded corners
						to compare boundaries.
					</Text>
					<Text>
						No gradients or substitute effects. Native support is under test; accepted values alone
						do not prove drawing.
					</Text>
				</View>
			</ScrollableArea>
		</SafeArea>
	)
}
