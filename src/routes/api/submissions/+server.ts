import { json } from '@sveltejs/kit';
import { compileLean } from '../../../lib/server/lean.ts';
import type { RequestHandler } from './$types';

const maxBodyBytes = 256 * 1024;

export const POST: RequestHandler = async ({ request, locals }) => {
	if (!locals.auth().userId) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}
	if (request.headers.get('content-type')?.split(';')[0].trim() !== 'application/json') {
		return json({ error: 'Expected application/json' }, { status: 415 });
	}

	// Limit the streamed body too: Content-Length can be missing or inaccurate.
	const reader = request.body?.getReader();
	const chunks: Uint8Array[] = [];
	let size = 0;
	let body: unknown;
	try {
		if (reader) {
			while (true) {
				const { done, value } = await reader.read();
				if (done) break;
				size += value.byteLength;
				if (size > maxBodyBytes) {
					await reader.cancel();
					return json({ error: 'Submission is too large' }, { status: 413 });
				}
				chunks.push(value);
			}
		}
		body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
	} catch {
		return json({ error: 'Invalid JSON body' }, { status: 400 });
	} finally {
		reader?.releaseLock();
	}
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
