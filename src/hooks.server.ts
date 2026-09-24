import { sequence } from '@sveltejs/kit/hooks';
import { withClerkHandler } from 'svelte-clerk/server';
import { connectDatabase } from '$lib/server/db';

export const handle = sequence(withClerkHandler(), async ({ event, resolve }) => {
	await connectDatabase();

	return resolve(event);
});
