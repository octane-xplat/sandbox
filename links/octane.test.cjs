const assert = require('node:assert/strict')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const { test } = require('node:test')
const createHooks = require('./octane-config.cjs')

function fixture(t) {
	const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'sandbox-links-'))

	t.after(() => fs.rmSync(directory, { recursive: true, force: true }))

	const write = (file, value) => {
		fs.mkdirSync(path.dirname(path.join(directory, file)), { recursive: true })
		fs.writeFileSync(
			path.join(directory, file),
			typeof value === 'string' ? value : JSON.stringify(value),
		)
	}

	const root = {
		packageManager: 'bun@1.4.4',
		workspaces: { catalog: { octane: '0.16.3', 'typescript-classic': 'npm:typescript@5.9.3' } },
		patchedDependencies: { 'octane@0.16.3': 'patches/runtime.patch' },
		overrides: { esbuild: '0.27.7' },
	}

	const app = {
		name: '@octane-xplat/sandbox',
		dependencies: {
			'@octane-xplat/ui': 'catalog:xplat',
			octane: 'catalog:xplat',
			'app-only': '1.0.0',
		},
		devDependencies: { nativescript: '9.1.1' },
	}

	write('package.json', root)
	write('apps/mobile/package.json', {})
	write('packages/ui/package.json', { name: '@octane-xplat/ui', dependencies: { vite: '8.3.6' } })
	write('packages/create/compatibility.json', {
		frameworkPackages: ['@octane-xplat/ui'],
		packages: {},
	})

	write('patches/runtime.patch', 'fixture')
	write('app/package.json', app)
	return {
		directory,
		root,
		app,
		write,
		hooks: () => createHooks(directory, path.join(directory, 'app/package.json'), () => {}),
	}
}

test('links declared framework packages, aligns runtime pins, and preserves app files', (t) => {
	const f = fixture(t)
	const before = fs.readFileSync(path.join(f.directory, 'app/package.json'), 'utf8')
	const hooks = f.hooks()
	const effective = hooks.readPackage(structuredClone(f.app))

	assert.equal(effective.dependencies['@octane-xplat/ui'], `link:${f.directory}/packages/ui`)
	assert.equal(effective.dependencies.octane, '0.16.3')
	assert.equal(effective.dependencies['app-only'], '1.0.0')
	assert.equal(effective.devDependencies['typescript-classic'], 'npm:typescript@5.9.3')

	const config = hooks.updateConfig({
		patchedDependencies: {
			'octane@0.1.0': 'patches/old.patch',
			'app-only@1.0.0': 'custom/app.patch',
		},
	})

	assert.equal(config.patchedDependencies['octane@0.1.0'], undefined)
	assert.equal(
		config.patchedDependencies['octane@0.16.3'],
		path.join(f.directory, 'patches/runtime.patch'),
	)

	assert.equal(config.patchedDependencies['app-only@1.0.0'], 'custom/app.patch')
	assert.equal(config.overrides.octane, '0.16.3')
	assert.equal(config.overrides['nativescript>typescript'], 'npm:typescript@5.9.3')
	assert.equal(fs.readFileSync(path.join(f.directory, 'app/package.json'), 'utf8'), before)

	const unrelated = { name: 'unrelated', dependencies: { octane: 'old' } }

	assert.equal(hooks.readPackage(unrelated), unrelated)
	assert.equal(unrelated.dependencies.octane, 'old')
})

test('rejects invalid packages, missing catalogs and conflicting custom patches', (t) => {
	const f = fixture(t)

	assert.throws(
		() =>
			f.hooks().updateConfig({ patchedDependencies: { 'octane@0.16.3': 'custom/runtime.patch' } }),
		/App patch conflicts/,
	)

	f.root.workspaces.catalog.octane = 'catalog:missing'
	f.write('package.json', f.root)
	assert.throws(() => f.hooks().readPackage(structuredClone(f.app)), /Missing checkout catalog/)
	f.write('packages/ui/package.json', { name: 'wrong' })
	assert.throws(() => f.hooks(), /Expected @octane-xplat\/ui/)
})

test('reports a missing checkout without changing dependency files', () => {
	const appFile = path.join(__dirname, '../package.json')
	const before = fs.readFileSync(appFile, 'utf8')
	const result = spawnSync(
		process.execPath,
		[
			path.join(__dirname, 'dev-octane.cjs'),
			path.join(os.tmpdir(), 'missing-sandbox-checkout-' + process.pid),
		],
		{ encoding: 'utf8' },
	)

	assert.equal(result.status, 1)
	assert.match(result.stderr, /dev:octane/)
	assert.equal(fs.readFileSync(appFile, 'utf8'), before)
})
