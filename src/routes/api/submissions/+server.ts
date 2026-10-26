import { json } from '@sveltejs/kit';
import { readJsonBody } from '../../../lib/server/body.ts';
import { compileLean } from '../../../lib/server/lean.ts';
import type { RequestHandler } from './$types';

const maxBodyBytes = 256 * 1024;

export const POST: RequestHandler = async ({ request, locals }) => {
	if (!locals.auth().userId) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}
	const parsed = await readJsonBody(request, maxBodyBytes, 'Submission is too large');
	if (!parsed.ok) return parsed.response;
	const { body } = parsed;
	if (
		!body ||
		typeof body !== 'object' ||
		!('source' in body) ||
		typeof body.source !== 'string' ||
		!body.source.trim()
	) {
		return json({ error: 'Expected a non-empty source string' }, { status: 400 });
	}

	try {
		return json(await compileLean(body.source), { headers: { 'cache-control': 'no-store' } });
	} catch (error) {
		console.error('Lean submission failed:', error);
		return json({ error: 'Lean compilation service unavailable' }, { status: 503 });
	}
};
