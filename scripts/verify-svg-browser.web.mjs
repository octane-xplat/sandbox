import assert from 'node:assert/strict'
import { chromium } from 'playwright'

// Text/DOM/layout only. Never capture screenshots or inspect image pixels.
const browser = await chromium.launch({
	headless: true,
	...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}),
})

const page = await browser.newPage()
const errors = []

page.on('pageerror', (error) => errors.push(error.message))
try {
	await page.goto(process.env.SVG_DEMO_URL ?? 'http://127.0.0.1:5203/')
	await page.waitForSelector('#svg-tinted circle')

	const measure = () =>
		page.evaluate(() => {
			const icon = document.querySelector('#svg-tinted')
			const image = document.querySelector('#svg-image')
			const asset = document.querySelector('#svg-asset')
			const ring = icon.querySelector('circle')
			const needle = icon.querySelector('path')
			const center = icon.querySelectorAll('circle')[1]

			return {
				width: icon.getBoundingClientRect().width,
				height: icon.getBoundingClientRect().height,
				imageWidth: image?.getBoundingClientRect().width,
				ringStroke: getComputedStyle(ring).stroke,
				ringFill: getComputedStyle(ring).fill,
				needleFill: getComputedStyle(needle).fill,
				centerFill: getComputedStyle(center).fill,
				centerStroke: getComputedStyle(center).stroke,
				assetTag: asset.tagName,
				assetInlineColor: asset.style.color,
				assetSrc: asset.getAttribute('src'),
				imageSrc: image?.getAttribute('src'),
				imageComplete: image?.complete,
				naturalWidth: image?.naturalWidth,
				module: document.querySelector('[data-testid="svg.module"]').textContent,
			}
		})

	await page.waitForFunction(
		() =>
			document.querySelector('#svg-image')?.naturalWidth > 0 &&
			document.querySelector('#svg-asset')?.naturalWidth > 0,
	)

	const initial = await measure()

	assert.equal(initial.width, 32)
	assert.equal(initial.height, 32)
	assert.equal(initial.naturalWidth, 32)
	assert.equal(initial.assetTag, 'IMG')
	assert.equal(initial.assetInlineColor, '')
	assert.equal(initial.assetSrc, initial.imageSrc)
	assert.equal(initial.ringStroke, 'rgb(37, 99, 235)')
	assert.equal(initial.ringFill, 'none')
	assert.equal(initial.needleFill, 'rgb(37, 99, 235)')

	const click = (id) => page.locator(`[data-testid="${id}"]`).click()

	await click('svg.large')
	await page.waitForFunction(
		() => document.querySelector('#svg-tinted').getBoundingClientRect().width === 80,
	)

	await click('svg.color')
	await page.waitForFunction(
		() => getComputedStyle(document.querySelector('#svg-tinted path')).fill === 'rgb(190, 18, 60)',
	)

	const changed = await measure()

	assert.equal(changed.height, 80)
	assert.equal(changed.assetInlineColor, '')
	assert.equal(changed.imageWidth, 80)
	assert.equal(changed.ringStroke, 'rgb(190, 18, 60)')
	assert.equal(changed.centerFill, 'rgb(245, 158, 11)')
	assert.equal(changed.centerStroke, 'rgb(124, 45, 18)')
	await page.evaluate(() => {
		globalThis.svgImageEvents = []

		const image = document.querySelector('#svg-image')

		image.addEventListener('load', () => globalThis.svgImageEvents.push('load'))
		image.addEventListener('error', () => globalThis.svgImageEvents.push('error'))
	})

	await click('svg.failure')
	await page.waitForFunction(() => globalThis.svgImageEvents.includes('error'))

	const failed = await measure()

	assert.equal(failed.imageComplete, true)
	assert.equal(failed.naturalWidth, 0)
	await click('svg.failure')
	await page.waitForFunction(() => globalThis.svgImageEvents.includes('load'))

	const events = await page.evaluate(() => globalThis.svgImageEvents)

	await click('svg.remount')
	assert.equal(await page.locator('#svg-image').count(), 0)
	await click('svg.remount')
	await page.waitForFunction(() => document.querySelector('#svg-image')?.naturalWidth > 0)
	await click('svg.small')
	await page.waitForFunction(
		() => document.querySelector('#svg-tinted').getBoundingClientRect().width === 24,
	)

	const narrowLayouts = []
	for (const width of [375, 428, 768]) {
		await page.setViewportSize({ width, height: 926 })
		const layout = await page.evaluate(() => ({
			viewport: innerWidth,
			scrollWidth: document.documentElement.scrollWidth,
			boxes: [...document.querySelectorAll('.card, .controls button, #svg-description')].map((host) => {
				const rect = host.getBoundingClientRect()
				return { id: host.id || host.dataset.testid, x: rect.x, width: rect.width, height: rect.height }
			}),
		}))
		assert.ok(layout.scrollWidth <= width, 'document must not overflow horizontally')
		for (const box of layout.boxes) {
			assert.ok(box.x >= -1 && box.x + box.width <= width + 1, 'card/control must fit viewport: ' + box.id)
		}
		if (width <= 428) {
			assert.ok(layout.boxes.find((box) => box.id === 'svg-description').height > 30)
		}
		narrowLayouts.push(layout)
	}
	assert.equal(await page.locator('#svg-unknown').count(), 0)
	assert.deepEqual(errors, [])
	console.log(
		JSON.stringify(
			{ initial, changed, failed, events, restored: await measure(), narrowLayouts, pageErrors: errors },
			null,
			2,
		),
	)
} finally {
	await browser.close()
}
