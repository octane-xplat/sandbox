import { defineConfig, xplatNative } from 'octane-xplat/vite'

// The shared preset owns the renderer rules, octane→universal/native alias,
// suffix extension chain, deps-bundle plugin exclusions, the HMR watchdog,
// the px→dip CSS rewrite, and fs.allow widening for link:/file: dep roots.
// App-specific additions go through the second argument's `extra` (or
// mergeConfig).
export default defineConfig(({ mode }) =>
	xplatNative(mode, {
		// Local source links otherwise resolve a second copy inside the framework's
		// Bun installation. The test host and mountXplat must share one registry.
		extra: { resolve: { dedupe: ['@nativescript/unit-test-runner'] } },
	}),
)
