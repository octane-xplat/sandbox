import type { Visibility } from './visibility-types'

// CSS collapse is layout-dependent. Removal on web explicitly uses display:none.
export function visibilityStyle(visibility: Visibility) {
	return {
		visibility: visibility === 'hidden' ? ('hidden' as const) : ('visible' as const),
		display: visibility === 'collapse' ? 'none' : 'flex',
	}
}
