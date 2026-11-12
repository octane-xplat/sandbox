export type GridProfileRequest = {
	scenario: 'scroll' | 'jump'
	dataset: 1001 | 10001
}

export function parseGridProfileRequest(value: string | null): GridProfileRequest | null {
	const match = /^(scroll|jump):(1001|10001)$/.exec(value ?? '')

	return match
		? { scenario: match[1] as 'scroll' | 'jump', dataset: Number(match[2]) as 1001 | 10001 }
		: null
}

export interface GridProfileDriver {
	begin(): void
	end(): void
	scroll(offset: number): void
	first(): void
	last(): void
}

// Native smooth-scroll bursts use the same offsets and cadence on both OSes.
// This is a repeatable programmatic workload, not an OS gesture/fling test.
export function runGridProfile(request: GridProfileRequest, driver: GridProfileDriver) {
	let active = false
	const timers: ReturnType<typeof setTimeout>[] = []
	const schedule = (delay: number, action: () => void) => {
		timers.push(setTimeout(action, delay))
	}

	schedule(3000, () => {
		active = true
		driver.begin()
	})

	if (request.scenario === 'scroll') {
		const offsets = [576, 1152, 1728, 2304, 2880, 3456, 2880, 2304, 1728, 1152, 576, 0]

		offsets.forEach((offset, index) => schedule(3000 + index * 1200, () => driver.scroll(offset)))
		schedule(17400, () => {
			driver.end()
			active = false
		})
	} else {
		for (let index = 0; index < 6; index++) {
			schedule(3000 + index * 1000, () => (index % 2 === 0 ? driver.last() : driver.first()))
		}

		schedule(9000, () => {
			driver.end()
			active = false
		})
	}

	return () => {
		timers.forEach(clearTimeout)
		if (active) {
			driver.end()
		}
	}
}
