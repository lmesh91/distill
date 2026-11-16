/** who a link is shown to: everyone, or only visitors who are signed in or signed out */
export type Audience = 'everyone' | 'signed-in' | 'signed-out';

export interface NavLink {
	label: string;
	href: '/' | '/app' | '/app/lean' | '/sign-in' | '/sign-up';
	audience: Audience;
	/** true when this link should be highlighted for the current path */
	isActive: (pathname: string) => boolean;
}

function within(path: string, root: string): boolean {
	return path === root || path.startsWith(`${root}/`);
}

/**
 * the site's primary pages in the order they appear in the navigation bar
 * add new top-level pages here as they are built
 */
export const primaryLinks: NavLink[] = [
	{ label: 'Home', href: '/', audience: 'everyone', isActive: (path) => path === '/' },
	// /app is the game's home; /app/lean is the sandbox, so don't highlight play there
	// the game needs an account, so signed-out visitors get the sign-in links instead
	{ label: 'Play', href: '/app', audience: 'signed-in', isActive: (path) => path === '/app' },
	{
		label: 'Sandbox',
		href: '/app/lean',
		audience: 'signed-in',
		isActive: (path) => within(path, '/app/lean')
	}
];

/** the account links on the right of the navigation bar; signing out is a button, not a link */
export const accountLinks: NavLink[] = [
	{
		label: 'Sign in',
		href: '/sign-in',
		audience: 'signed-out',
		isActive: (path) => within(path, '/sign-in')
	},
	{
		label: 'Sign up',
		href: '/sign-up',
		audience: 'signed-out',
		isActive: (path) => within(path, '/sign-up')
	}
];

/** the links someone should see, given whether they are signed in */
export function visibleLinks(links: NavLink[], signedIn: boolean): NavLink[] {
	return links.filter(
		(link) =>
			link.audience === 'everyone' || link.audience === (signedIn ? 'signed-in' : 'signed-out')
	);
}
