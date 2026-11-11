const fs = require('node:fs')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

const appRoot = path.resolve(__dirname, '..')

// Hoisted installs can retain package-local links after switching out of local mode.
// Only this app's disposable installation is removed; the checkout is untouched.
fs.rmSync(path.join(appRoot, 'node_modules'), { recursive: true, force: true })

const result = spawnSync('pnpm', ['install', '--frozen-lockfile'], {
	cwd: appRoot,
	stdio: 'inherit',
	shell: process.platform === 'win32',
})

if (result.error) {
	console.error(result.error.message)
}

process.exitCode = result.status ?? 1
