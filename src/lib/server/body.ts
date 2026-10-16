import { json } from '@sveltejs/kit';

export type JsonBodyResult = { ok: true; body: unknown } | { ok: false; response: Response };

export async function readJsonBody(
	request: Request,
	maxBytes: number,
	tooLargeMessage = 'Request body is too large'
): Promise<JsonBodyResult> {
	if (request.headers.get('content-type')?.split(';')[0].trim() !== 'application/json') {
		return { ok: false, response: json({ error: 'Expected application/json' }, { status: 415 }) };
	}

	// Limit the streamed body too: Content-Length can be missing or inaccurate.
	const reader = request.body?.getReader();
	const chunks: Uint8Array[] = [];
	let size = 0;
	try {
		if (reader) {
			while (true) {
				const { done, value } = await reader.read();
				if (done) break;
				size += value.byteLength;
				if (size > maxBytes) {
					await reader.cancel();
					return { ok: false, response: json({ error: tooLargeMessage }, { status: 413 }) };
				}
				chunks.push(value);
			}
		}
		return { ok: true, body: JSON.parse(Buffer.concat(chunks).toString('utf8')) };
	} catch {
		return { ok: false, response: json({ error: 'Invalid JSON body' }, { status: 400 }) };
	} finally {
		reader?.releaseLock();
	}
}
