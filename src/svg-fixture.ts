import assetUrl from './assets/compass.svg'
import explicitUrl from './assets/compass.svg?url'
import source from './assets/compass.svg?raw'
import { createIconRegistry } from '@octane-xplat/ui'

// Icon.markup expects inner SVG, not a URL or path d string. This conversion
// is specific to our trusted authored fixture; it is not an SVG sanitizer.
export const viewBox = '0 0 32 32'
export const markup = source.replace(/^<svg\b[^>]*>/, '').replace(/<\/svg>\s*$/, '')
export const icons = createIconRegistry()

icons.registerIcon('compass-tinted', { markup, viewBox })
icons.registerIcon('compass-asset', { src: assetUrl })

export { assetUrl, explicitUrl, source }
