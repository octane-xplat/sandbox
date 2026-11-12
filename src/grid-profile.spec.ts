import { expect, it } from 'vitest'
import { beginGridProfile, endGridProfile } from './profile-platform'

// Typechecking cannot establish that the custom Swift class is present in
// NativeScript metadata. Exercise the actual bridge in each device runtime.
it('can emit a complete native profiling interval', () => {
  expect(() => {
    beginGridProfile()
    endGridProfile()
  }).not.toThrow()
})
