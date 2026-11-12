import type { GridProfileRequest } from './grid-profile'

// Browser/default leaf: profiling uses native traces on iOS and Android.
export function readGridProfile(): GridProfileRequest | null {
	return null
}

export function beginGridProfile() {}
export function endGridProfile() {}
