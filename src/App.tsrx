import { useState } from 'octane'
import {
	SafeArea,
	ScrollableArea,
	VStack,
	HStack,
	Text,
	Button,
	Icon,
	Image,
} from '@octane-xplat/ui'

import { assetUrl, explicitUrl, icons, source } from './svg-fixture'

export function App() @{
	const [size, setSize] = useState(32)
	const [color, setColor] = useState('#2563eb')
	const [missing, setMissing] = useState(false)
	const [mounted, setMounted] = useState(true)

	<SafeArea id="svg-page" className="page">
		<ScrollableArea id="svg-scroll" className="viewport">
			<VStack id="svg-content" className="app">
				<Text className="title">Imported SVG lab</Text>
				<Text>One authored compass, three supported render paths.</Text>
				<HStack className="controls">
					<Button testID="svg.small" label="24 px" clickAction={() => setSize(24)} />
					<Button testID="svg.large" label="80 px" clickAction={() => setSize(80)} />
					<Button
						testID="svg.color"
						label="Blue / rose"
						clickAction={() => setColor(color === '#2563eb' ? '#be123c' : '#2563eb')}
					/>
				</HStack>
				<Text testID="svg.settings">{'size=' + size + '; color=' + color}</Text>
				<VStack id="svg-card-tinted" className="card">
					<Text className="heading">Tintable registered Icon</Text>
					<Text id="svg-description">
						?raw → inner markup → registry. Ring stroke and needle fill use currentColor. Amber
						center and brown stroke stay fixed.
					</Text>
					<Icon
						id="svg-tinted"
						name="compass-tinted"
						registry={icons}
						size={size}
						color={color}
						accessibilityLabel="Tintable imported compass"
					/>
				</VStack>
				<VStack id="svg-card-asset" className="card">
					<Text className="heading">Default import → Icon.src</Text>
					<Text>Asset source. Icon.color does not recolor an external SVG image.</Text>
					<Icon
						id="svg-asset"
						name="compass-asset"
						registry={icons}
						size={size}
						color={color}
						accessibilityLabel="Asset imported compass"
					/>
				</VStack>
				<VStack id="svg-card-image" className="card">
					<Text className="heading">Default import → Image.src</Text>
					<Text>
						Toggle a missing file URL, then restore. No shared SVG load/error callbacks or
						placeholder contract.
					</Text>
					<HStack className="controls">
						<Button
							testID="svg.failure"
							label="Missing / valid source"
							clickAction={() => setMissing(!missing)}
						/>
						<Button
							testID="svg.remount"
							label="Unmount / mount image"
							clickAction={() => setMounted(!mounted)}
						/>
					</HStack>
					<Text testID="svg.image-state">
						{!mounted
							? 'unmounted'
							: missing
								? 'missing source requested'
								: 'valid source requested'}
					</Text>
					@if (mounted) {
						<Image
							id="svg-image"
							src={missing ? '/__missing_compass.svg' : assetUrl}
							alt="Image imported compass"
							contentFit="contain"
							style={{ width: size, height: size }}
						/>
					}
				</VStack>
				<Text className="heading">Module facts</Text>
				<Text testID="svg.module">
					{'default: ' +
						typeof assetUrl +
						'; ?url equals default: ' +
						(assetUrl === explicitUrl) +
						'; ?raw starts with svg: ' +
						source.startsWith('<svg')}
				</Text>
				<Text>Unknown icon names render nothing:</Text>
				<Icon id="svg-unknown" name="unregistered-compass" registry={icons} size={size} />
			</VStack>
		</ScrollableArea>
	</SafeArea>
}
