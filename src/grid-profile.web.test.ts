import { afterEach, expect, it, vi } from 'vitest'
import { parseGridProfileRequest, runGridProfile } from './grid-profile'

afterEach(() => vi.useRealTimers())

it('accepts only the supported profiling requests', () => {
	expect(parseGridProfileRequest('scroll:10001')).toEqual({ scenario: 'scroll', dataset: 10001 })
	expect(parseGridProfileRequest('jump:1001')).toEqual({ scenario: 'jump', dataset: 1001 })
	for (const input of [null, '', 'scroll:999', 'scroll:1001:extra', 'fling:1001']) {
		expect(parseGridProfileRequest(input)).toBeNull()
	}
})

it('marks only the scrolling window and cleans up pending work', () => {
	vi.useFakeTimers()

	const driver = { begin: vi.fn(), end: vi.fn(), scroll: vi.fn(), first: vi.fn(), last: vi.fn() }
	const cancel = runGridProfile({ scenario: 'scroll', dataset: 1001 }, driver)

	vi.advanceTimersByTime(2999)
	expect(driver.begin).not.toHaveBeenCalled()
	vi.advanceTimersByTime(14401)
	expect(driver.begin).toHaveBeenCalledOnce()
	expect(driver.end).toHaveBeenCalledOnce()
	expect(driver.scroll.mock.calls.map(([offset]) => offset)).toEqual([
		576, 1152, 1728, 2304, 2880, 3456, 2880, 2304, 1728, 1152, 576, 0,
	])

	cancel()
	expect(driver.end).toHaveBeenCalledOnce()
	expect(vi.getTimerCount()).toBe(0)
})

it('keeps jumps separate and closes an interrupted measurement', () => {
	vi.useFakeTimers()

	const driver = { begin: vi.fn(), end: vi.fn(), scroll: vi.fn(), first: vi.fn(), last: vi.fn() }
	const cancel = runGridProfile({ scenario: 'jump', dataset: 10001 }, driver)

	vi.advanceTimersByTime(4500)
	expect(driver.last).toHaveBeenCalledOnce()
	expect(driver.first).toHaveBeenCalledOnce()
	expect(driver.scroll).not.toHaveBeenCalled()
	cancel()
	vi.advanceTimersByTime(20000)
	expect(driver.end).toHaveBeenCalledOnce()
	expect(driver.last).toHaveBeenCalledOnce()
	expect(vi.getTimerCount()).toBe(0)
})
