import { json, redirect, type Handle } from '@sveltejs/kit';
import { normalizedRouteId } from './routes.ts';

function within(path: string, root: string): boolean {
	return path === root || path.startsWith(`${root}/`);
}

// Run after Clerk populates locals, before database access or route handlers.
export const protectRoutes: Handle = ({ event, resolve }) => {
	const path = normalizedRouteId(event);
	const appRoute = within(path, '/app');
	const accountApi = within(path, '/api') && path !== '/api/webhooks/clerk';

	if ((appRoute || accountApi) && !event.locals.auth().userId) {
		if (accountApi) {
			return json({ error: 'Unauthorized' }, { status: 401 });
		}

		// Clerk restores the requested page (including its query) after sign-in.
		// 303 also turns rejected form submissions into a GET of the sign-in page.
		redirect(303, `/sign-in?redirect_url=${encodeURIComponent(event.url.href)}`);
	}

	return resolve(event);
};
