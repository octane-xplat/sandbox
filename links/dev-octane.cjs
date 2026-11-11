const fs = require('node:fs')
const path = require('node:path')
const { spawnSync } = require('node:child_process')
const createHooks = require('./octane-config.cjs')

const appRoot = path.resolve(__dirname, '..')
const link = path.join(__dirname, 'octane-xplat')
function run(command, args, cwd) {
	const result = spawnSync(command, args, {
		cwd,
		stdio: 'inherit',
		shell: process.platform === 'win32',
	})

	if (result.error) {
		throw result.error
	}

	if (result.status !== 0) {
		const error = new Error(`${command} exited with status ${result.status ?? 1}`)

		error.exitCode = result.status ?? 1
		throw error
	}
}

try {
	if (process.argv.length > 3) {
		throw new Error('Usage: pnpm dev:octane [/absolute/path/to/octane-xplat]')
	}

	const supplied = process.argv[2]

	if (!supplied && !fs.existsSync(link)) {
		throw new Error('Choose a prepared checkout: pnpm dev:octane /absolute/path/to/octane-xplat')
	}

	const checkout = fs.realpathSync(supplied ? path.resolve(supplied) : link)

	// Validate the checkout before changing the saved link or installing anything.
	createHooks(checkout, path.join(appRoot, 'package.json'), () => {}).updateConfig({})

	const existing = fs.lstatSync(link, { throwIfNoEntry: false })

	if (existing && !existing.isSymbolicLink()) {
		throw new Error('links/octane-xplat exists and is not a symbolic link; move it yourself first.')
	}

	if (existing && fs.realpathSync(link) !== checkout) {
		fs.unlinkSync(link)
	}

	if (!fs.existsSync(link)) {
		fs.symlinkSync(checkout, link, process.platform === 'win32' ? 'junction' : 'dir')
	}

	// A frozen checkout install restores package-local links affected by hoisted pnpm.
	run('bun', ['install', '--frozen-lockfile', '--ignore-scripts'], checkout)
	try {
		run(
			'pnpm',
			['install', '--ignore-scripts', '--lockfile=false', '--config.pnpmfile=./links/octane.cjs'],
			appRoot,
		)
	} finally {
		// Restore checkout links even when the consumer install fails.
		run('bun', ['install', '--frozen-lockfile', '--ignore-scripts'], checkout)
	}

	console.log('Local framework installed. Start with pnpm dev. Restore with pnpm dev:published.')
} catch (error) {
	console.error(`[dev:octane] ${error.message}`)
	process.exitCode = error.exitCode || 1
}
