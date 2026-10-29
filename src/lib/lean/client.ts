export type Diagnostic = {
	severity: number;
	message: string;
	range: { start: { line: number; character: number } };
};

export type LineTranslation = { line: number; english: string };

type Callbacks = {
	onstatus: (status: string) => void;
	ondiagnostics: (diagnostics: Diagnostic[]) => void;
	/** `null` when Lean could not translate, e.g. the document doesn't `import Distill` */
	ontranslation?: (lines: LineTranslation[] | null) => void;
};

// Lean drops RPC sessions that receive no keep-alive for 30 seconds.
const keepAliveMs = 10_000;
const rpcNeedsReconnect = -32900;

// Each editor has its own relay connection and therefore its own Lean document.
export function connectLean(socket: WebSocket, initialCode: string, callbacks: Callbacks) {
	const uri = 'file:///Scratch.lean';
	let code = initialCode;
	let version = 1;
	let opened = false;
	let disposed = false;
	let nextId = 1;
	// Lean sends session ids as strings because they don't fit in a JavaScript number.
	let sessionId: string | undefined;
	let keepAlive: ReturnType<typeof setInterval> | undefined;
	let checkedVersion = 0;
	const pending = new Map<number, (message: { result?: unknown; error?: { code: number; message: string } }) => void>();

	function send(method: string, params: unknown, id?: number) {
		if (socket.readyState === WebSocket.OPEN) {
			socket.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
		}
	}

	function request(method: string, params: unknown, onresponse: Parameters<typeof pending.set>[1]) {
		const id = nextId++;
		pending.set(id, onresponse);
		send(method, params, id);
	}

	function stopKeepAlive() {
		clearInterval(keepAlive);
		keepAlive = undefined;
		sessionId = undefined;
	}

	function connectRpc() {
		request('$/lean/rpc/connect', { uri }, ({ result, error }) => {
			if (error || disposed) return;
			sessionId = (result as { sessionId: string }).sessionId;
			clearInterval(keepAlive);
			keepAlive = setInterval(() => send('$/lean/rpc/keepAlive', { uri, sessionId }), keepAliveMs);
			translate();
		});
	}

	// Translate once Lean has finished checking the current version, so a real translator can use
	// the elaborated proof.
	function translate() {
		if (!callbacks.ontranslation || !sessionId || checkedVersion !== version) return;
		const requestedVersion = version;
		request(
			'$/lean/rpc/call',
			{
				textDocument: { uri },
				position: { line: 0, character: 0 },
				sessionId,
				method: 'Distill.translate',
				params: {}
			},
			({ result, error }) => {
				if (disposed || requestedVersion !== version) return;
				if (error?.code === rpcNeedsReconnect) {
					stopKeepAlive();
					connectRpc();
				} else {
					callbacks.ontranslation?.(error ? null : (result as LineTranslation[]));
				}
			}
		);
	}

	callbacks.onstatus('Connecting…');
	socket.onopen = () => send('initialize', { processId: null, rootUri: null, capabilities: {} }, 0);
	socket.onclose = (event) => {
		opened = false;
		stopKeepAlive();
		pending.clear();
		callbacks.onstatus(
			event.reason ? `Disconnected: ${event.reason}` : 'Disconnected. Is the relay running?'
		);
	};
	socket.onerror = () => callbacks.onstatus('Unable to connect to Lean. Is the relay running?');
	socket.onmessage = (event) => {
		const message = JSON.parse(event.data);
		if (message.id === 0 && !message.method) {
			if (message.error) {
				callbacks.onstatus(`Lean initialization failed: ${message.error.message}`);
				return;
			}
			send('initialized', {});
			send('textDocument/didOpen', {
				textDocument: { uri, languageId: 'lean4', version, text: code }
			});
			opened = true;
			callbacks.onstatus('Checking…');
			if (callbacks.ontranslation) connectRpc();
		} else if (!message.method && pending.has(message.id)) {
			const onresponse = pending.get(message.id)!;
			pending.delete(message.id);
			onresponse(message);
		} else if (message.method && message.id !== undefined) {
			// Lean requests a file watcher; this in-memory document doesn't need one.
			socket.send(JSON.stringify({ jsonrpc: '2.0', id: message.id, result: null }));
		} else if (message.method === 'textDocument/publishDiagnostics') {
			if (message.params.uri === uri && message.params.version === version) {
				callbacks.ondiagnostics(message.params.diagnostics);
			}
		} else if (message.method === '$/lean/fileProgress') {
			const document = message.params.textDocument;
			if (document.uri === uri && document.version === version) {
				const done = message.params.processing.length === 0;
				callbacks.onstatus(done ? 'Done' : 'Checking…');
				if (done && checkedVersion !== version) {
					checkedVersion = version;
					translate();
				}
			}
		}
	};

	return {
		update(nextCode: string) {
			if (disposed || nextCode === code) return;
			code = nextCode;
			callbacks.ondiagnostics([]);
			if (!opened || socket.readyState !== WebSocket.OPEN) return;
			callbacks.onstatus('Checking…');
			send('textDocument/didChange', {
				textDocument: { uri, version: ++version },
				contentChanges: [{ text: code }]
			});
		},
		dispose() {
			if (disposed) return;
			disposed = true;
			stopKeepAlive();
			pending.clear();
			if (opened) send('textDocument/didClose', { textDocument: { uri } });
			socket.onopen = socket.onmessage = socket.onerror = socket.onclose = null;
			socket.close();
		}
	};
}
