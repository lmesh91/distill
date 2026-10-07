import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = ({ locals }) => {
	const { userId } = locals.auth();

	if (!userId) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	return json({ userId });
};
