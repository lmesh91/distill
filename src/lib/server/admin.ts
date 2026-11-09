import { isHttpError, json, redirect, type Handle } from '@sveltejs/kit';
import { requireAdmin } from './roles.ts';

/** Protect every request, including page data, form actions, and API mutations. */
export const handleAdmin: Handle = ({ event, resolve }) => {
	// The matched route handles encoded URLs, rerouting, and deployment base paths.
	// Route groups do not appear in URLs and must not affect authorization.
	const path = event.route.id ? event.route.id.replace(/\([^/]+\)\//g, '') : event.url.pathname;
	if (['/admin', '/api/admin'].some((root) => path === root || path.startsWith(`${root}/`))) {
		try {
			requireAdmin(event.locals);
		} catch (error) {
			if (!isHttpError(error, 401) && !isHttpError(error, 403)) throw error;
			if (path === '/api/admin' || path.startsWith('/api/admin/')) {
				return json({ error: error.body.message }, { status: error.status });
			}
			if (error.status === 401) {
				const returnTo = event.url.pathname + event.url.search;
				redirect(303, `/sign-in?redirect_url=${encodeURIComponent(returnTo)}`);
			}
			throw error;
		}
	}
	return resolve(event);
};
