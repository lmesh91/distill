import { redirect } from '@sveltejs/kit';
import { safeRedirectPath } from '$lib/server/redirects';
import type { LayoutServerLoad } from './$types';

// signed-in users don't need the sign-in or sign-up pages, so send them on to the game
// (or back to the page they were trying to reach if there is one)
export const load: LayoutServerLoad = ({ locals, url }) => {
	if (locals.auth().userId) {
		redirect(303, safeRedirectPath(url.searchParams.get('redirect_url'), url.origin, '/app'));
	}
};
