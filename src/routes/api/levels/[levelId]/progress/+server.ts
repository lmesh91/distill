import { json } from '@sveltejs/kit';
import { ObjectId } from 'mongodb';
import { readJsonBody } from '$lib/server/body';
import { getLevels, getUserLevelProgresses } from '$lib/server/collections';
import { saveLevelProgress } from '$lib/server/progress';
import type { RequestHandler } from './$types';

const maxBodyBytes = 256 * 1024;
const maxClockSkewMs = 5 * 60 * 1000;

export const PUT: RequestHandler = async ({ request, params, locals }) => {
	const { userId } = locals.auth();
	if (!userId) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}
	if (!ObjectId.isValid(params.levelId)) {
		return json({ error: 'Level not found' }, { status: 404 });
	}

	const parsed = await readJsonBody(request, maxBodyBytes, 'Code is too large');
	if (!parsed.ok) return parsed.response;
	const { body } = parsed;
	if (
		!body ||
		typeof body !== 'object' ||
		!('code' in body) ||
		typeof body.code !== 'string' ||
		!('savedAt' in body) ||
		typeof body.savedAt !== 'number' ||
		!Number.isFinite(body.savedAt) ||
		body.savedAt <= 0
	) {
		return json(
			{ error: 'Expected a code string and a savedAt timestamp in milliseconds' },
			{ status: 400 }
		);
	}
	// A far-future timestamp would mark every later save as stale.
	if (body.savedAt > Date.now() + maxClockSkewMs) {
		return json({ error: 'savedAt is in the future' }, { status: 400 });
	}

	try {
		const result = await saveLevelProgress(getLevels(), getUserLevelProgresses(), {
			userId,
			levelId: new ObjectId(params.levelId),
			code: body.code,
			clientSavedAt: new Date(body.savedAt)
		});
		if (result === 'level_not_found') {
			return json({ error: 'Level not found' }, { status: 404 });
		}
		if (result === 'stale') {
			return json({ error: 'A newer save already exists' }, { status: 409 });
		}
		return new Response(null, { status: 204 });
	} catch (error) {
		console.error('Saving level progress failed:', error);
		return json({ error: 'Could not save progress' }, { status: 503 });
	}
};
