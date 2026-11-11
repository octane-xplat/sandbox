const fs = require('node:fs')
const path = require('node:path')
const { isDeepStrictEqual } = require('node:util')

const sections = ['dependencies', 'devDependencies', 'optionalDependencies']
const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'))

// Explicitly selected by dev:octane; ordinary pnpm installs never load this hook.
module.exports = function createHooks(checkout, appFile, log = console.log) {
	const root = readJson(path.join(checkout, 'package.json'))

	if (!root.packageManager?.startsWith('bun@')) {
		throw new Error('Use a current Bun-based Octane Xplat checkout.')
	}

	const compatibility = readJson(path.join(checkout, 'packages/create/compatibility.json'))
	const framework = new Set(compatibility.frameworkPackages)
	const app = readJson(appFile)
	const links = new Map()
	const manifests = [root, readJson(path.join(checkout, 'apps/mobile/package.json'))]

	for (const section of sections) {
		for (const name of Object.keys(app[section] || {})) {
			if (!framework.has(name)) {
				continue
			}

			const directory = path.join(
				checkout,
				'packages',
				name === 'octane-xplat' ? 'toolchain' : name.replace('@octane-xplat/', ''),
			)

			const manifest = readJson(path.join(directory, 'package.json'))

			if (manifest.name !== name) {
				throw new Error(`Expected ${name} in ${directory}`)
			}

			links.set(name, directory)
			manifests.push(manifest)
		}
	}

	function resolve(name, spec) {
		if (!spec.startsWith('catalog:')) {
			return spec
		}

		const catalog = spec.slice(8)
		const value = (catalog ? root.workspaces?.catalogs?.[catalog] : root.workspaces?.catalog)?.[
			name
		]

		if (typeof value !== 'string' || value.startsWith('catalog:')) {
			throw new Error(`Missing checkout catalog entry: ${name} (${spec})`)
		}

		return value
	}

	function external(name) {
		if (root.workspaces?.catalog?.[name]) {
			return resolve(name, root.workspaces.catalog[name])
		}

		// Linked packages' runtime pins take precedence over root development tools.
		for (const [sources, fields] of [
			[manifests.slice(2), ['dependencies', 'optionalDependencies']],
			[manifests, sections],
		]) {
			const specs = new Set()

			for (const manifest of sources) {
				for (const field of fields) {
					const spec = manifest[field]?.[name]

					if (spec && !spec.startsWith('workspace:')) {
						specs.add(resolve(name, spec))
					}
				}
			}

			if (specs.size > 1) {
				throw new Error(`Conflicting checkout versions for ${name}: ${[...specs].join(', ')}`)
			}

			if (specs.size) {
				return [...specs][0]
			}
		}

		const managed = compatibility.packages[name]

		return managed?.specifier || managed?.version
	}

	function readPackage(pkg) {
		if (pkg.name !== app.name) {
			return pkg
		}

		for (const section of sections) {
			for (const name of Object.keys(pkg[section] || {})) {
				const spec = links.has(name) ? `link:${links.get(name)}` : external(name)

				if (spec) {
					pkg[section][name] = spec
				}
			}
		}

		for (const name of ['typescript-classic', '@tsrx/content-mapper']) {
			if (!sections.some((section) => pkg[section]?.[name]) && external(name)) {
				pkg.devDependencies ||= {}
				pkg.devDependencies[name] = external(name)
			}
		}

		return pkg
	}

	return {
		readPackage,
		updateConfig(config) {
			const effective = readPackage(structuredClone(app))
			// patches/ is exclusively the official creator's patch snapshot.
			const patchedDependencies = Object.fromEntries(
				Object.entries(config.patchedDependencies || {}).filter(([, file]) => {
					const relative = path
						.relative(path.dirname(appFile), path.resolve(path.dirname(appFile), file))
						.replaceAll('\\', '/')

					return !relative.startsWith('patches/')
				}),
			)

			const shared = {}

			for (const section of sections) {
				for (const [name, spec] of Object.entries(effective[section] || {})) {
					if (!links.has(name) && spec !== app[section]?.[name]) {
						shared[name] = spec
					}
				}
			}

			if (effective.devDependencies?.nativescript && external('typescript-classic')) {
				shared['nativescript>typescript'] = external('typescript-classic')
			}

			// In this sandbox the checkout owns managed versions; app-only overrides remain.
			const overrides = {
				...config.overrides,
				...root.overrides,
				...compatibility.overrides,
				...shared,
			}

			for (const [selector, file] of Object.entries(root.patchedDependencies || {})) {
				const separator = selector.indexOf('@', 1)
				const name = selector.slice(0, separator)
				const version = selector.slice(separator + 1)

				if (/^https?:/.test(version)) {
					if (
						sections.some((section) => effective[section]?.[name] === version) ||
						overrides[name] === version
					) {
						throw new Error(`pnpm cannot apply the selected URL patch: ${selector}`)
					}

					continue
				}

				if (patchedDependencies[selector]) {
					throw new Error(`App patch conflicts with checkout: ${selector}`)
				}

				const absolute = path.resolve(checkout, file)

				if (!fs.statSync(absolute, { throwIfNoEntry: false })?.isFile()) {
					throw new Error(`Missing checkout patch: ${absolute}`)
				}

				patchedDependencies[selector] = absolute
			}

			const packageExtensions = { ...config.packageExtensions }

			for (const [name, extension] of Object.entries(root.packageExtensions || {})) {
				if (packageExtensions[name] && !isDeepStrictEqual(packageExtensions[name], extension)) {
					throw new Error(`Conflicting package extension: ${name}`)
				}

				packageExtensions[name] = extension
			}

			for (const [name, directory] of links) {
				log(`[dev:octane] ${name} -> ${directory}`)
			}

			return {
				...config,
				overrides,
				patchedDependencies,
				packageExtensions,
				allowUnusedPatches: true,
				minimumReleaseAgeExclude: [
					...new Set([
						...(config.minimumReleaseAgeExclude || []),
						...(root.minimumReleaseAgeExclude || []),
					]),
				],
			}
		},
	}
}
