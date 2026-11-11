// Real Chromium layout, no screenshots. Runs its own isolated headless browser.
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { once } from 'node:events'
import { writeFile } from 'node:fs/promises'
import { chromium } from 'playwright'

const port = 4183
const url = `http://127.0.0.1:${port}`
const server = spawn(
	'pnpm',
	['exec', 'vite', '--host', '127.0.0.1', '--port', String(port), '--strictPort'],
	{ stdio: ['ignore', 'pipe', 'pipe'] },
)

let output = ''

server.stdout.on('data', (chunk) => {
	output += chunk
})

server.stderr.on('data', (chunk) => {
	output += chunk
})

let browser
const results = []

try {
	const deadline = Date.now() + 30_000

	while (true) {
		try {
			if ((await fetch(url)).ok) {
				break
			}
		} catch {}

		if (server.exitCode != null || Date.now() > deadline) {
			throw new Error(`Vite did not start: ${output}`)
		}

		await new Promise((resolve) => setTimeout(resolve, 150))
	}

	browser = await chromium.launch(
		process.env.CHROMIUM_EXECUTABLE
			? { executablePath: process.env.CHROMIUM_EXECUTABLE }
			: { channel: 'chrome' },
	)

	const page = await browser.newPage({ viewport: { width: 900, height: 1000 } })
	const errors = []

	page.on('pageerror', (error) => errors.push(error.message))
	await page.goto(url)

	const get = (id) => page.getByTestId(`fit.${id}`)

	await get('wrapped.text').waitFor()

	const sample = async (label) => {
		await page.waitForFunction(
			() =>
				!document
					.querySelector('[data-testid="fit.wrapped.bounds"]')
					.textContent.includes('Waiting'),
		)

		await page.evaluate(
			() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
		)

		const cases = await page.evaluate(() => {
			const rect = (el) => {
				const r = el.getBoundingClientRect()

				return { x: r.x, y: r.y, width: r.width, height: r.height }
			}

			return Object.fromEntries(
				['intrinsic', 'wrapped', 'limited', 'conflict', 'stretch'].map((name) => {
					const find = (part) => document.querySelector(`[data-testid="fit.${name}.${part}"]`)
					const box = find('box'),
						text = find('text'),
						style = getComputedStyle(box)

					const range = document.createRange()

					range.selectNodeContents(text)
					return [
						name,
						{
							parent: rect(find('parent')),
							box: rect(box),
							text: rect(text),
							content: text.textContent,
							glyphRange: rect(range),
							lineRects: [...range.getClientRects()].map((r) => ({
								x: r.x,
								y: r.y,
								width: r.width,
								height: r.height,
							})),
							style: {
								width: style.width,
								minWidth: style.minWidth,
								maxWidth: style.maxWidth,
								alignSelf: style.alignSelf,
								padding: style.padding,
								boxSizing: style.boxSizing,
								textWhiteSpace: getComputedStyle(text).whiteSpace,
							},
							liveBounds: find('bounds').textContent.trim(),
						},
					]
				}),
			)
		})

		results.push({ label, viewport: page.viewportSize(), cases })
		return cases
	}

	const near = (actual, expected, message) =>
		assert.ok(Math.abs(actual - expected) < 1, `${message}: ${actual} vs ${expected}`)

	const short = await sample('short, 300 parent, 12 padding')

	near(
		short.intrinsic.box.width,
		short.intrinsic.glyphRange.width + 24,
		'short hugs content + padding',
	)

	near(short.wrapped.box.width, short.intrinsic.box.width, 'wrapped short hugs too')
	near(short.limited.box.width, 180, 'minimum floor')
	near(short.conflict.box.width, 260, 'minimum wins conflicting maximum')
	near(short.stretch.box.width, 300, 'stretch fills parent')
	await get('long').click()

	const long = await sample('long, 300 parent, 12 padding')

	assert.ok(long.intrinsic.box.width > 300, 'uncapped single line exceeds parent')
	near(
		long.intrinsic.box.width,
		long.intrinsic.glyphRange.width + 24,
		'single-line content + padding',
	)

	near(long.wrapped.box.width, 300, 'long wrapped cap')
	near(long.limited.box.width, 240, 'maximum caps long text')
	assert.ok(long.wrapped.text.height > short.wrapped.text.height, 'wrapped text gains height')
	assert.ok(long.wrapped.lineRects.length > 1, 'actual multiline range')
	await get('width').click()

	const narrow = await sample('long, 220 parent, 12 padding')

	near(narrow.wrapped.box.width, 220, 'parent cap follows resize')
	near(narrow.stretch.box.width, 220, 'stretch follows resize')
	assert.ok(narrow.wrapped.text.height > long.wrapped.text.height, 'narrowing adds lines')
	await get('short').click()

	const shrunk = await sample('short again, 220 parent, 12 padding')

	near(shrunk.intrinsic.box.width, short.intrinsic.box.width, 'shrinks after long to short')
	await get('padding').click()

	const padded = await sample('short, 220 parent, 24 padding')

	near(
		padded.wrapped.box.width - shrunk.wrapped.box.width,
		24,
		'padding adds exactly 24 total width',
	)

	near(
		padded.wrapped.box.height - shrunk.wrapped.box.height,
		24,
		'padding adds exactly 24 total height',
	)

	await get('input').fill('Typed dynamically')
	await page.waitForFunction(
		() =>
			document.querySelector('[data-testid="fit.wrapped.text"]').textContent ===
			'Typed dynamically',
	)

	const typed = await sample('custom input')

	assert.ok(typed.wrapped.box.width > padded.wrapped.box.width, 'input resizes box')
	await get('token').click()
	await sample('unbroken token')
	await get('reset').click()
	await page.setViewportSize({ width: 390, height: 844 })

	const mobile = await sample('reset, phone-width browser viewport')

	near(mobile.wrapped.box.width, short.wrapped.box.width, 'phone-width viewport keeps short hug')
	near(mobile.stretch.box.width, 300, 'phone-width stretch')
	assert.deepEqual(errors, [], 'no browser runtime errors')
	console.log(JSON.stringify({ browser: await browser.version(), results, passed: true }, null, 2))
} finally {
	if (process.env.LAYOUT_OUTPUT) {
		await writeFile(process.env.LAYOUT_OUTPUT, JSON.stringify(results, null, 2))
	}

	await browser?.close()
	server.kill('SIGTERM')
	if (server.exitCode == null) {
		await once(server, 'exit')
	}
}
