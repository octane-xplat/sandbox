// No image capture. Optional external Playwright install; no app dependency.
import assert from 'node:assert/strict'

const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright')
const browser = await chromium.launch({
	executablePath:
		process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
	headless: true,
})

try {
	const page = await browser.newPage({ viewport: { width: 900, height: 900 } })
	const errors = []

	page.on('pageerror', (error) => errors.push(error.message))
	await page.goto(process.env.DEMO_URL || 'http://127.0.0.1:5187')
	await page.locator('[data-testid="shadow.preview"]').waitFor()

	const measure = () =>
		page.evaluate(() => {
			const read = (id) => {
				const element = document.querySelector(`[data-testid="shadow.${id}"]`)
				const style = getComputedStyle(element)
				const rect = element.getBoundingClientRect()
				const marker = element.querySelector('.overflow-marker')
				const child = marker.getBoundingClientRect()
				const label = element.firstElementChild.getBoundingClientRect()
				const markerLabel = marker.firstElementChild.getBoundingClientRect()

				return {
					display: style.display,
					labelCenterX: label.left + label.width / 2 - (rect.left + rect.width / 2),
					labelCenterY: label.top + label.height / 2 - (rect.top + rect.height / 2),
					markerCenterX: markerLabel.left + markerLabel.width / 2 - (child.left + child.width / 2),
					markerCenterY: markerLabel.top + markerLabel.height / 2 - (child.top + child.height / 2),
					shadow: style.boxShadow,
					radius: style.borderRadius,
					overflow: style.overflow,
					width: rect.width,
					height: rect.height,
					childExtends: child.right > rect.right,
				}
			}

			return { preview: read('preview'), control: read('control') }
		})

	const click = (id) => page.locator(`[data-testid="shadow.${id}"]`).click()
	const assertCentered = (state) => {
		for (const sample of [state.preview, state.control]) {
			assert.equal(sample.display, 'flex')
			for (const delta of [sample.labelCenterX, sample.labelCenterY, sample.markerCenterX, sample.markerCenterY]) {
				assert.ok(Math.abs(delta) < 1, `Label center differs by ${delta}px`)
			}
		}
	}
	const initial = await measure()
	assertCentered(initial)

	assert.match(initial.preview.shadow, /6px 8px 14px 4px inset/)
	assert.equal(initial.control.shadow, 'none')
	assert.equal(initial.preview.width, initial.control.width)
	assert.equal(initial.preview.height, initial.control.height)
	console.log('INITIAL', JSON.stringify(initial))
	// Every radius × clipping combination, with the shadow still inset.
	for (const rounded of [true, false]) {
		for (const clipped of [false, true]) {
			await click('reset')
			if (!rounded) {
				await click('rounded')
			}

			if (clipped) {
				await click('clip')
			}

			const state = await measure()
			assertCentered(state)

			assert.equal(state.preview.radius, rounded ? '24px' : '0px')
			assert.equal(state.preview.overflow, clipped ? 'hidden' : 'visible')
			assert.match(state.preview.shadow, /inset/)
			assert.equal(state.preview.width, initial.preview.width)
			assert.equal(state.preview.height, initial.preview.height)
			assert.equal(state.preview.childExtends, true)
			console.log('SHAPE', JSON.stringify(state))
		}
	}

	await click('reset')
	for (const id of ['x.plus', 'y.minus', 'blur.minus', 'spread.minus', 'color.00000080']) {
		await click(id)
	}

	const changed = await measure()

	assert.match(changed.preview.shadow, /8px 6px 12px 2px inset/)
	assert.match(changed.preview.shadow, /rgba\(0, 0, 0, 0.5\)/)
	console.log('CHANGED', JSON.stringify(changed))
	// Exercise signed offsets/spread and the zero-blur boundary.
	for (let index = 0; index < 12; index++) {
		for (const name of ['x', 'y', 'blur', 'spread']) {
			await click(name + '.minus')
		}
	}

	const negative = await measure()

	assert.match(negative.preview.shadow, /-16px -18px 0px -12px inset/)
	console.log('NEGATIVE', JSON.stringify(negative))
	await click('toggle')
	assert.equal((await measure()).preview.shadow, 'none')
	await click('reset')
	assert.deepEqual(await measure(), initial)
	assert.deepEqual(errors, [])
	console.log('PASS: computed styles and layout only; no rendered appearance assertions.')
} finally {
	await browser.close()
}
