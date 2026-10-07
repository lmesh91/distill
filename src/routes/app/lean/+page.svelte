<script lang="ts">
	import { onMount } from 'svelte';

	type Diagnostic = {
		severity: number;
		message: string;
		range: { start: { line: number; character: number } };
	};

	// Lean resolves imports from the project the relay runs it in, so the URI can be anything.
	const uri = 'file:///Scratch.lean';
	const severities = ['', 'Error', 'Warning', 'Info', 'Hint'];

	let code = $state('import Distill\n\nexample : 1 + 1 = 2 := by\n  rfl\n');
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
	let version = 1;
	let opened = false;
	let socket: WebSocket;

	function send(method: string, params: unknown, id?: number) {
		socket.send(JSON.stringify({ jsonrpc: '2.0', id, method, params }));
	}

	function sendChange() {
		if (!opened) return;
		send('textDocument/didChange', {
			textDocument: { uri, version: ++version },
			contentChanges: [{ text: code }]
		});
	}

	onMount(() => {
		socket = new WebSocket(
			`${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/lean`
		);
		socket.onopen = () =>
			send('initialize', { processId: null, rootUri: null, capabilities: {} }, 0);
		socket.onclose = (event) =>
			(status = event.reason
				? `Disconnected: ${event.reason}`
				: 'Disconnected. Is the relay running?');
		socket.onmessage = (event) => {
			const message = JSON.parse(event.data);
			if (message.id === 0 && !message.method) {
				send('initialized', {});
				send('textDocument/didOpen', {
					textDocument: { uri, languageId: 'lean4', version, text: code }
				});
				opened = true;
			} else if (message.method && message.id !== undefined) {
				// Lean asks to register a file watcher, which this page doesn't need.
				socket.send(JSON.stringify({ jsonrpc: '2.0', id: message.id, result: null }));
			} else if (message.method === 'textDocument/publishDiagnostics') {
				// Ignore results for text that has since been edited.
				if (message.params.version === version) diagnostics = message.params.diagnostics;
			} else if (message.method === '$/lean/fileProgress') {
				if (message.params.textDocument.version === version) {
					status = message.params.processing.length > 0 ? 'Checking…' : 'Done';
				}
			}
		};
		return () => socket.close();
	});
</script>

<svelte:head><title>Lean · Distill</title></svelte:head>

<h1>Lean</h1>

<p>Connection Status: <span role="status">{status}</span></p>

<textarea bind:value={code} oninput={sendChange} spellcheck="false" rows="12" cols="80"></textarea>

<ul>
	{#each diagnostics as diagnostic, index (index)}
		<li>
			{severities[diagnostic.severity]} at line {diagnostic.range.start.line + 1}, column
			{diagnostic.range.start.character + 1}:
			<pre>{diagnostic.message}</pre>
		</li>
	{/each}
</ul>
