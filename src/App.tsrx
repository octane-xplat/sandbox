import { useState } from 'octane'
import {
	View,
	Text,
	Pressable,
	TextInput,
	VStack,
	HStack,
	SafeArea,
	useMeasure,
} from '@octane-xplat/ui'

import { SHORT_TEXT, LONG_TEXT, TOKEN_TEXT } from './samples'

function Sample(props: {
	name: string
	title: string
	note: string
	text: string
	width: number
	padding: number
	variant: string
}) {
	const parent = useMeasure()
	const box = useMeasure()
	const text = useMeasure()

	return (
		<VStack className="sample" gap={2}>
			<Text className="sample-title">{props.title}</Text>
			<Text className="note">{props.note}</Text>
			<View
				ref={parent.ref}
				testID={`fit.${props.name}.parent`}
				className="lane"
				style={{ width: props.width }}
			>
				<View
					ref={box.ref}
					testID={`fit.${props.name}.box`}
					className={['box', props.variant]}
					alignSelf={props.variant === 'stretch' ? 'stretch' : 'flex-start'}
					style={{ padding: props.padding }}
				>
					<View className="content" ref={text.ref} testID={`fit.${props.name}.content`}>
						<Text
							testID={`fit.${props.name}.text`}
							className="sample-text"
							maxLines={props.variant === 'intrinsic' ? 1 : undefined}
						>
							{props.text}
						</Text>
					</View>
				</View>
			</View>
			<Text testID={`fit.${props.name}.bounds`} className="measurement">
				{parent.bounds && box.bounds && text.bounds
					? `Parent ${parent.bounds.width.toFixed(1)} · box ${box.bounds.width.toFixed(1)} × ${box.bounds.height.toFixed(1)} · content host ${text.bounds.width.toFixed(1)} × ${text.bounds.height.toFixed(1)} DIP`
					: 'Waiting for layout…'}
			</Text>
		</VStack>
	)
}

export function App() {
	const [text, setText] = useState(SHORT_TEXT)
	const [width, setWidth] = useState(300)
	const [padding, setPadding] = useState(12)

	return (
		<SafeArea>
			<VStack className="app" gap={4} isScrollable>
				<Text className="title">Fit to text</Text>
				<Text>
					Auto width + cross-axis start alignment. Compare content sizing with width limits and
					stretch.
				</Text>
				<HStack gap={2} wrap="wrap">
					<Pressable testID="fit.short" className="button" onPress={() => setText(SHORT_TEXT)}>
						<Text>Short text</Text>
					</Pressable>
					<Pressable testID="fit.long" className="button" onPress={() => setText(LONG_TEXT)}>
						<Text>Long text</Text>
					</Pressable>
					<Pressable testID="fit.token" className="button" onPress={() => setText(TOKEN_TEXT)}>
						<Text>Unbroken word</Text>
					</Pressable>
				</HStack>
				<TextInput
					testID="fit.input"
					accessibilityLabel="Sample text"
					value={text}
					onChange={setText}
				/>
				<HStack gap={2} wrap="wrap">
					<Pressable
						testID="fit.width"
						className="button secondary"
						onPress={() => setWidth(width === 300 ? 220 : 300)}
					>
						<Text>{`Parent: ${width} DIP (toggle)`}</Text>
					</Pressable>
					<Pressable
						testID="fit.padding"
						className="button secondary"
						onPress={() => setPadding(padding === 12 ? 24 : 12)}
					>
						<Text>{`Padding: ${padding} DIP (toggle)`}</Text>
					</Pressable>
					<Pressable
						testID="fit.reset"
						className="button secondary"
						onPress={() => {
							setText(SHORT_TEXT)
							setWidth(300)
							setPadding(12)
						}}
					>
						<Text>Reset</Text>
					</Pressable>
				</HStack>
				<Sample
					name="intrinsic"
					title="Intrinsic, single line"
					note="Auto width, alignSelf=flex-start, maxLines=1; deliberately uncapped. Long text may exceed the lane."
					text={text}
					width={width}
					padding={padding}
					variant="intrinsic"
				/>
				<Sample
					name="wrapped"
					title="Hug, capped by parent"
					note="Auto width, alignSelf=flex-start, max-width:100%, min-width:0; unlimited text lines."
					text={text}
					width={width}
					padding={padding}
					variant="wrapped"
				/>
				<Sample
					name="limited"
					title="Hug, minimum + maximum"
					note="Same alignment; min-width:180, max-width:240 DIP. The minimum can leave empty space."
					text={text}
					width={width}
					padding={padding}
					variant="limited"
				/>
				<Sample
					name="conflict"
					title="Conflicting limits"
					note="min-width:260, max-width:200 DIP. Test which limit wins, including in the narrow lane."
					text={text}
					width={width}
					padding={padding}
					variant="conflict"
				/>
				<Sample
					name="stretch"
					title="Stretch comparison"
					note="Auto width, alignSelf=stretch; same text and padding, full parent width."
					text={text}
					width={width}
					padding={padding}
					variant="stretch"
				/>
				<Text className="note">
					Bounds are live container/content-wrapper rectangles, not glyph ink. Widths are CSS pixels
					on web and DIPs on phones. Single-line text is a truncation API; inspect measurements
					before assuming intrinsic overflow on native. An unbroken word may overflow without a
					word-break policy.
				</Text>
			</VStack>
		</SafeArea>
	)
}
