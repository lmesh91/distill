import { sequence } from '@sveltejs/kit/hooks';
import { withClerkHandler } from 'svelte-clerk/server';
import { connectDatabase } from '$lib/server/db';
import { handleAdmin } from '$lib/server/admin';
import { protectRoutes } from '$lib/server/auth';

export const handle = sequence(
    withClerkHandler(),
    protectRoutes,
    handleAdmin,
    async ({ event, resolve }) => {
        await connectDatabase();
        return resolve(event);
    }
);
