import { parseGridProfileRequest } from './grid-profile'

// Implemented in App_Resources/iOS/src/GridProfileTrace.swift.
declare class GridProfileTrace extends NSObject {
	static begin(): void
	static end(): void
}

export function readGridProfile() {
	if (import.meta.env.VITE_GRID_PROFILING !== '1') {
		return null
	}

	return parseGridProfileRequest(NSProcessInfo.processInfo.environment.objectForKey('GRID_PROFILE'))
}

export function beginGridProfile() {
	GridProfileTrace.begin()
}

export function endGridProfile() {
	GridProfileTrace.end()
}
