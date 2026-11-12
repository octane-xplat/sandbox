/** @jsxImportSource @octane-xplat/jsx */
// Native-only comparison leaf: no public UI components in this vocabulary.
export function BareText() @{
	<masonview>
		<label id="bare-visible" text="visible" />
		<label id="bare-inline-hidden" text="hidden inline" style={{ visibility: 'hidden' }} />
		<label id="bare-class-hidden" text="hidden class" className="probe-hidden" />
		<label id="bare-inline-collapse" text="collapse inline" style={{ visibility: 'collapse' }} />
	</masonview>
}
