import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { on, once } from 'node:events';
import { after, before, test } from 'node:test';
import { WebSocket } from 'ws';

const port = 8082;
const url = `ws://127.0.0.1:${port}/lean`;
const relay = spawn(process.execPath, ['relay/server.ts'], {
	env: { ...process.env, LEAN_RELAY_PORT: String(port) },
	stdio: ['ignore', 'pipe', 'inherit']
});

before(() => once(relay.stdout, 'data'), { timeout: 10_000 });
after(() => relay.kill());

test('Lean checks a document that imports the Distill project', { timeout: 60_000 }, async () => {
	const ws = new WebSocket(url, { origin: 'http://localhost:5173' });
	const send = (method: string, params: unknown, id?: number) =>
		ws.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
	await once(ws, 'open');
	send('initialize', { processId: null, rootUri: null, capabilities: {} }, 0);

	for await (const [data] of on(ws, 'message')) {
		const message = JSON.parse(data.toString());
		if (message.id === 0) {
			send('initialized', {});
			send('textDocument/didOpen', {
				textDocument: {
					uri: 'file:///Scratch.lean',
					languageId: 'lean4',
					version: 1,
					text: 'import Distill\nexample : hello = "world" := rfl\nexample : 1 + 1 = 3 := rfl\n'
				}
			});
		} else if (message.method === 'textDocument/publishDiagnostics') {
			const errors = message.params.diagnostics.filter(
				(d: { severity: number }) => d.severity === 1
			);
			if (errors.length > 0) {
				assert.deepEqual(
					errors.map((d: { range: { start: { line: number } } }) => d.range.start.line),
					[2]
				);
				break;
			}
		}
	}
	ws.close();
});

test('relay rejects pages from other origins', async () => {
	const ws = new WebSocket(url, { origin: 'https://example.com' });
	const [error] = await once(ws, 'error');
	assert.match(error.message, /401/);
});
