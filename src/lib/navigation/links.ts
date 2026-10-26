export interface NavLink {
	label: string;
	href: '/' | '/app' | '/app/lean';
	/** true when this link should be highlighted for the current path */
	isActive: (pathname: string) => boolean;
}

/**
 * the site's primary pages in the order they appear in the navigation bar
 * add new top-level pages here as they are built
 */
export const primaryLinks: NavLink[] = [
	{ label: 'Home', href: '/', isActive: (path) => path === '/' },
	// /app is the game's home; /app/lean is the sandbox, so don't highlight play there
	{ label: 'Play', href: '/app', isActive: (path) => path === '/app' },
	{ label: 'Sandbox', href: '/app/lean', isActive: (path) => path.startsWith('/app/lean') }
];
