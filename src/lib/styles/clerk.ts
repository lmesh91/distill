/**
 * theme for Clerk's sign-in, sign-up and account components, matching tokens.css
 * Clerk builds its own color shades from these, so they're plain hex values instead of
 * CSS variables. keep them in sync with tokens.css
 * https://clerk.com/docs/customization/variables
 */
export const clerkAppearance = {
	variables: {
		colorPrimary: '#1a6db8', // --color-brand
		colorBackground: '#ffffff', // --color-surface
		colorDanger: '#b42318', // --color-error
		colorSuccess: '#1a7f37', // --color-success
		colorNeutral: '#1b1b1f', // --color-ink
		fontFamily: "'Space Grotesk Variable', system-ui, sans-serif", // --font-body
		borderRadius: '6px' // --radius
	},
	elements: {
		// the pixel border and shadow used by .card
		card: {
			border: '2px solid #1b1b1f',
			boxShadow: '4px 4px 0 #1b1b1f'
		}
	}
};
