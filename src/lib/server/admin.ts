import type { Handle } from '@sveltejs/kit';
import { requireAdmin } from './roles.ts';

/** Protect every request, including page data, form actions, and API mutations. */
export const handleAdmin: Handle = ({ event, resolve }) => {
	// The matched route handles encoded URLs, rerouting, and deployment base paths.
	// Route groups do not appear in URLs and must not affect authorization.
	const path = event.route.id ? event.route.id.replace(/\([^/]+\)\//g, '') : event.url.pathname;
	if (['/admin', '/api/admin'].some((root) => path === root || path.startsWith(`${root}/`))) {
		requireAdmin(event.locals);
	}
	return resolve(event);
};
