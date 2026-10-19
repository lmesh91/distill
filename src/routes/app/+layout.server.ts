import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = ({ locals, url }) => {
	// Track the URL so navigation within /app requests server data and runs the
	// auth hook again, including pages without their own server load function.
	void url.href;
	return { userId: locals.auth().userId };
};
