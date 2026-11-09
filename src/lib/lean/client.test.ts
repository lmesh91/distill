import assert from 'node:assert/strict';
import { test } from 'node:test';
import { connectLean, type Diagnostic } from './client.ts';

function setup() {
	const sent: { id?: number; method: string; params: Record<string, unknown> }[] = [];
	const statuses: string[] = [];
	const diagnostics: Diagnostic[][] = [];
	let closed = false;
	const socket = {
		readyState: WebSocket.CONNECTING,
		onopen: null,
		onmessage: null,
		onclose: null,
		onerror: null,
		send: (data: string) => sent.push(JSON.parse(data)),
		close: () => (closed = true)
	} as unknown as WebSocket;
	const client = connectLean(socket, 'example : True := by\n  trivial', {
		onstatus: (status) => statuses.push(status),
		ondiagnostics: (items) => diagnostics.push(items)
	});
	const receive = (message: unknown) =>
		socket.onmessage?.call(socket, new MessageEvent('message', { data: JSON.stringify(message) }));
	return {
		client,
		socket,
		sent,
		statuses,
		diagnostics,
		receive,
		get closed() {
			return closed;
		},
		open() {
			Object.defineProperty(socket, 'readyState', { value: WebSocket.OPEN, configurable: true });
			socket.onopen?.call(socket, new Event('open'));
			receive({ id: 0, result: {} });
		}
	};
}

test('opens with the latest code even when edited before Lean initializes', () => {
	const session = setup();
	session.client.update('example : 1 = 1 := rfl');
	session.open();
	assert.deepEqual(
		session.sent.map((message) => message.method),
		['initialize', 'initialized', 'textDocument/didOpen']
	);
	assert.deepEqual(session.sent[2].params.textDocument, {
		uri: 'file:///Scratch.lean',
		languageId: 'lean4',
		version: 1,
		text: 'example : 1 = 1 := rfl'
	});
	session.client.dispose();
});

test('sends edits once and ignores diagnostics and progress for stale or other documents', () => {
	const session = setup();
	session.open();
	session.client.update('example : 1 = 2 := rfl');
	session.client.update('example : 1 = 2 := rfl');
	assert.equal(session.sent.length, 4);
	assert.deepEqual(session.sent[3], {
		jsonrpc: '2.0',
		method: 'textDocument/didChange',
		params: {
			textDocument: { uri: 'file:///Scratch.lean', version: 2 },
			contentChanges: [{ text: 'example : 1 = 2 := rfl' }]
		}
	});
	const error = { severity: 1, message: 'Not equal', range: { start: { line: 0, character: 0 } } };
	for (const [uri, version] of [
		['file:///Scratch.lean', 1],
		['file:///Other.lean', 2],
		['file:///Scratch.lean', 2]
	]) {
		session.receive({
			method: 'textDocument/publishDiagnostics',
			params: { uri, version, diagnostics: [error] }
		});
		session.receive({
			method: '$/lean/fileProgress',
			params: { textDocument: { uri, version }, processing: [] }
		});
	}
	assert.deepEqual(session.diagnostics, [[], [error]]);
	assert.deepEqual(session.statuses, ['Connecting…', 'Checking…', 'Checking…', 'Done']);
	session.client.dispose();
});

test('closes the document and removes socket handlers on disposal', () => {
	const session = setup();
	session.open();
	session.client.dispose();
	session.client.dispose();
	session.client.update('ignored');
	assert.equal(session.sent.length, 4);
	assert.equal(session.sent[3].method, 'textDocument/didClose');
	assert.equal(session.closed, true);
	assert.equal(session.socket.onopen, null);
	assert.equal(session.socket.onmessage, null);
	assert.equal(session.socket.onclose, null);
	assert.equal(session.socket.onerror, null);
});

test('requests a translation once Lean finishes checking the current version', () => {
	const sent: { id?: number; method: string; params: Record<string, unknown> }[] = [];
	const translations: unknown[] = [];
	const socket = {
		readyState: WebSocket.OPEN,
		send: (data: string) => sent.push(JSON.parse(data)),
		close: () => {}
	} as unknown as WebSocket;
	const client = connectLean(socket, 'example : True := trivial', {
		onstatus: () => {},
		ondiagnostics: () => {},
		ontranslation: (lines) => translations.push(lines)
	});
	const receive = (message: unknown) =>
		socket.onmessage?.call(socket, new MessageEvent('message', { data: JSON.stringify(message) }));
	const done = (version: number) =>
		receive({
			method: '$/lean/fileProgress',
			params: { textDocument: { uri: 'file:///Scratch.lean', version }, processing: [] }
		});

	receive({ id: 0, result: {} });
	const connect = sent.at(-1)!;
	assert.equal(connect.method, '$/lean/rpc/connect');
	done(1);
	assert.equal(sent.at(-1), connect, 'waits for the RPC session');

	receive({ id: connect.id, result: { sessionId: '18446744073709551615' } });
	const call = sent.at(-1)!;
	assert.equal(call.method, '$/lean/rpc/call');
	assert.equal(call.params.method, 'Distill.translate');
	assert.equal(call.params.sessionId, '18446744073709551615');

	client.update('example : True := by trivial');
	receive({ id: call.id, result: [{ line: 0, english: 'stale' }] });
	done(2);
	const next = sent.at(-1)!;
	receive({ id: next.id, result: [{ line: 0, english: 'fresh' }] });
	receive({ id: 999, error: { code: -32601, message: 'unrelated' } });
	assert.deepEqual(translations, [[{ line: 0, english: 'fresh' }]]);
	client.dispose();
});

test('allows editing after a disconnect without sending to a closed socket', () => {
	const session = setup();
	session.open();
	Object.defineProperty(session.socket, 'readyState', { value: WebSocket.CLOSED });
	session.socket.onclose?.call(session.socket, { reason: 'Lean exited' } as CloseEvent);
	session.client.update('example : True := by trivial');
	assert.equal(session.sent.length, 3);
	assert.equal(session.statuses.at(-1), 'Disconnected: Lean exited');
	session.client.dispose();
});
