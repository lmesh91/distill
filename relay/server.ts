import { spawn } from 'node:child_process';
import { StreamMessageReader, StreamMessageWriter } from 'vscode-jsonrpc/node';
import { WebSocketServer } from 'ws';

const port = Number(process.env.LEAN_RELAY_PORT ?? 8081);

const wss = new WebSocketServer({
	host: '127.0.0.1',
	port,
	path: '/lean',
	// Lean code can run arbitrary programs and any website can open a WebSocket to localhost,
	// so only accept pages served from this machine.
	verifyClient: ({ origin }: { origin: string }) =>
		['localhost', '127.0.0.1', '[::1]'].includes(URL.parse(origin)?.hostname ?? '')
});

// Each connection gets its own language server running in the Lean project, so the project's
// toolchain and imports are used. LSP messages are forwarded unchanged in both directions.
wss.on('connection', (ws) => {
	const lean = spawn('lake', ['serve'], {
		cwd: new URL('../lean/', import.meta.url),
		stdio: ['pipe', 'pipe', 'inherit']
	});
	const reader = new StreamMessageReader(lean.stdout);
	const writer = new StreamMessageWriter(lean.stdin);

	reader.listen((message) => ws.send(JSON.stringify(message)));
	ws.on('message', (data) => {
		try {
			writer.write(JSON.parse(data.toString())).catch(() => ws.close());
		} catch {
			ws.close(1007, 'Expected JSON');
		}
	});

	// Killing `lake serve` closes Lean's stdin, which shuts down the rest of its process tree.
	ws.on('close', () => lean.kill());
	ws.on('error', console.error);
	lean.on('error', (error) => {
		console.error(`Cannot start Lean: ${error.message}`);
		ws.close(1011, 'Cannot start Lean');
	});
	lean.on('exit', () => ws.close(1011, 'Lean exited'));
});

wss.on('listening', () => console.log(`Lean relay listening on ws://127.0.0.1:${port}/lean`));
