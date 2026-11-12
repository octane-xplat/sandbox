import { Application } from '@nativescript/core'
import { parseGridProfileRequest } from './grid-profile'

export function readGridProfile() {
	if (import.meta.env.VITE_GRID_PROFILING !== '1') {
		return null
	}

	return parseGridProfileRequest(
		Application.android.startActivity?.getIntent().getStringExtra('GRID_PROFILE') ?? null,
	)
}

export function beginGridProfile() {
	if (android.os.Build.VERSION.SDK_INT >= 29) {
		android.os.Trace.beginAsyncSection('GridProfile', 1)
	}
}

export function endGridProfile() {
	if (android.os.Build.VERSION.SDK_INT >= 29) {
		android.os.Trace.endAsyncSection('GridProfile', 1)
	}
}
