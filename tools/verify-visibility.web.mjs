// Nonvisual browser geometry/input check. Uses the local framework's existing
// Playwright installation; never downloads a browser or captures images.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { createServer } from 'vite'

const framework = fs.realpathSync('links/octane-xplat')
const frameworkRequire = createRequire(path.join(framework, 'tools/visual/package.json'))
const { chromium } = frameworkRequire('playwright')
const server = await createServer({
	server: { port: 0, strictPort: false },
	optimizeDeps: { entries: ['index.html'] },
})

await server.listen()

let browser
const evidence = []

try {
	browser = await chromium.launch({ headless: true })

	const page = await browser.newPage({ viewport: { width: 800, height: 1000 } })
	const errors = []

	page.on('pageerror', (error) => errors.push(error.message))
	await page.goto(server.resolvedUrls.local[0])
	for (const prefix of ['simple', 'layered']) {
		if (prefix === 'layered') {
			await page.getByTestId('probe.layered').click()
		}

		const target = (id) => page.getByTestId(prefix + '.' + id)

		await target('visible').waitFor()

		const sample = async (id) =>
			target(id).evaluate((el) => {
				const rect = el.getBoundingClientRect()
				const parent = el.parentElement.getBoundingClientRect()
				const style = getComputedStyle(el)

				return {
					visibility: style.visibility,
					display: style.display,
					x: rect.x - parent.x,
					width: rect.width,
					height: rect.height,
					text: el.textContent,
				}
			})

		assert.equal((await sample('initial-hidden')).visibility, 'hidden')
		assert.equal((await sample('initial-hidden')).width, 80)
		assert.equal((await sample('initial-collapse')).width, 0)
		assert.equal(await target('conditional').count(), 0)
		await target('text').click()
		await page.waitForFunction(
			(prefix) =>
				document
					.querySelector(`[data-testid="${prefix}.inline"]`)
					?.textContent.includes('changed while hidden'),
			prefix,
		)

		for (let cycle = 0; cycle < 3; cycle++) {
			for (const mode of ['collapse', 'visible', 'hidden']) {
				await target('next').click()
				await page.waitForFunction(
					({ prefix, mode }) =>
						document.querySelector(`[data-testid="${prefix}.next"]`)?.textContent.includes(mode),
					{ prefix, mode },
				)

				for (const id of ['inline', 'class']) {
					const state = await sample(id)

					assert.equal(state.visibility, mode === 'hidden' ? 'hidden' : 'visible')
					assert.equal(state.width, mode === 'collapse' ? 0 : 80)
					assert.equal(
						(await sample(id + '-after')).x,
						mode === 'collapse' ? 0 : 80,
						JSON.stringify({
							prefix,
							cycle,
							mode,
							id,
							state,
							after: await sample(id + '-after'),
							parent: await target(id).evaluate((el) => ({
								html: el.parentElement.outerHTML,
								display: getComputedStyle(el.parentElement).display,
								direction: getComputedStyle(el.parentElement).flexDirection,
							})),
						}),
					)

					evidence.push({ prefix, cycle, mode, id, ...state })
				}

				await target('resize').click()
				await target('input').click()
			}

			await target('mount').click()
			await target('conditional').waitFor()
			assert.equal((await sample('conditional-after')).x, 80)
			await target('mount').click()
			await target('conditional').waitFor({ state: 'detached' })
			assert.equal((await sample('conditional-after')).x, 0)
		}

		assert.equal(await target('input').textContent(), 'Input 9')
		assert.ok(Number(await target('heartbeat').textContent()) > 3)
		await page.setViewportSize({ width: 600, height: 900 })
		evidence.push({
			prefix,
			heartbeat: await target('heartbeat').textContent(),
			input: await target('input').textContent(),
		})
	}

	assert.deepEqual(errors, [])

	const modules = [...server.environments.client.moduleGraph.idToModuleMap.keys()]
	const textModules = modules.filter((id) => id.includes('/components/content/Text.web.tsrx'))

	assert.ok(textModules.some((id) => id.startsWith(framework + '/packages/ui/')))

	const octaneModules = modules.filter((id) => id.includes('/octane/') && id.includes('/runtime/'))

	console.log(
		JSON.stringify(
			{ browser: await browser.version(), framework, textModules, octaneModules, evidence },
			null,
			2,
		),
	)
} finally {
	await browser?.close()
	await server.close()
}
