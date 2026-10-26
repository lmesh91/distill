export type Diagnostic = {
	severity: number;
	message: string;
	range: { start: { line: number; character: number } };
};

type Callbacks = {
	onstatus: (status: string) => void;
	ondiagnostics: (diagnostics: Diagnostic[]) => void;
};

// Each editor has its own relay connection and therefore its own Lean document.
export function connectLean(socket: WebSocket, initialCode: string, callbacks: Callbacks) {
	const uri = 'file:///Scratch.lean';
	let code = initialCode;
	let version = 1;
	let opened = false;
	let disposed = false;

	function send(method: string, params: unknown, id?: number) {
		if (socket.readyState === WebSocket.OPEN) {
			socket.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
		}
	}

	callbacks.onstatus('Connecting…');
	socket.onopen = () => send('initialize', { processId: null, rootUri: null, capabilities: {} }, 0);
	socket.onclose = (event) => {
		opened = false;
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
				callbacks.onstatus(message.params.processing.length > 0 ? 'Checking…' : 'Done');
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
			if (opened) send('textDocument/didClose', { textDocument: { uri } });
			socket.onopen = socket.onmessage = socket.onerror = socket.onclose = null;
			socket.close();
		}
	};
}
