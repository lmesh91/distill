/**
 * theme for Clerk's sign-in, sign-up and account components, matching tokens.css (#192)
 * the values are our CSS variables, so Clerk follows light and dark mode (including the theme
 * toggle) without re-rendering. Clerk mixes its hover and border shades from these with
 * color-mix(), which every browser we support has
 * https://clerk.com/docs/react/guides/customizing-clerk/appearance-prop/variables
 */
export const clerkAppearance = {
	variables: {
		colorPrimary: 'var(--color-brand)',
		colorPrimaryForeground: 'var(--color-text-on-brand)',
		colorBackground: 'var(--color-surface)',
		colorForeground: 'var(--color-text)',
		colorMutedForeground: 'var(--color-text-muted)',
		colorInput: 'var(--color-surface)',
		colorInputForeground: 'var(--color-text)',
		// borders, dividers and hover backgrounds are shades of this, so they flip with the theme
		colorNeutral: 'var(--color-ink)',
		colorDanger: 'var(--color-error)',
		colorSuccess: 'var(--color-success)',
		colorWarning: 'var(--color-warning)',
		colorRing: 'var(--color-focus)',
		fontFamily: 'var(--font-body)',
		borderRadius: 'var(--radius)'
	},
	elements: {
		// the pixel border and shadow used by .card
		card: {
			border: 'var(--border-width) solid var(--color-border)',
			boxShadow: 'var(--shadow-pixel)'
		}
	}
};
