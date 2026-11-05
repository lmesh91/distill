import { json, type RequestHandler } from '@sveltejs/kit';
import { readJsonBody } from './body.ts';
import { isVerificationTarget, verifyLean } from './verification.ts';
import { LeanBusyError } from './leanJobs.ts';
import type { VerificationTarget } from '../types/submission.ts';

type LoadLevel = (slug: string) => Promise<{ verification?: VerificationTarget } | null>;
const maxBodyBytes = 256 * 1024;

/** The lookup must only return published levels from the trusted server database. */
export function createSubmissionHandler(loadLevel: LoadLevel): RequestHandler {
	return async ({ request, locals }) => {
		if (!locals.auth().userId) return json({ error: 'Unauthorized' }, { status: 401 });
		const parsed = await readJsonBody(request, maxBodyBytes, 'Submission is too large');
		if (!parsed.ok) return parsed.response;
		const { body } = parsed;
		if (
			!body ||
			typeof body !== 'object' ||
			!('source' in body) ||
			typeof body.source !== 'string' ||
			!body.source.trim() ||
			!('levelSlug' in body) ||
			typeof body.levelSlug !== 'string' ||
			!body.levelSlug.trim()
		) {
			return json({ error: 'Expected non-empty source and levelSlug strings' }, { status: 400 });
		}
		try {
			const level = await loadLevel(body.levelSlug);
			if (!level) return json({ error: 'Level not found' }, { status: 404 });
			if (!isVerificationTarget(level.verification)) {
				return json({ error: 'Level verification is not configured' }, { status: 503 });
			}
			return json(await verifyLean(body.source, level.verification, request.signal), {
				headers: { 'cache-control': 'no-store' }
			});
		} catch (error) {
			if (error instanceof LeanBusyError) {
				return json(
					{ error: 'Lean verification is busy; try again shortly' },
					{
						status: 503,
						headers: { 'retry-after': '1', 'cache-control': 'no-store' }
					}
				);
			}
			console.error('Lean submission failed:', error);
			return json({ error: 'Lean verification service unavailable' }, { status: 503 });
		}
	};
}
