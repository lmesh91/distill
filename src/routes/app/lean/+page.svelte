<script lang="ts">
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import type { Diagnostic } from '$lib/lean/client';
	const severities = ['', 'Error', 'Warning', 'Info', 'Hint'];

	let code = $state('import Distill\n\nexample : 1 + 1 = 2 := by\n  rfl\n');
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
</script>

<svelte:head><title>Lean · Distill</title></svelte:head>

<h1>Lean</h1>

<p>Connection Status: <span role="status">{status}</span></p>

<LeanEditor
	bind:value={code}
	onstatus={(nextStatus) => (status = nextStatus)}
	ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
/>

<ul>
	{#each diagnostics as diagnostic, index (index)}
		<li>
			{severities[diagnostic.severity]} at line {diagnostic.range.start.line + 1}, column
			{diagnostic.range.start.character + 1}:
			<pre>{diagnostic.message}</pre>
		</li>
	{/each}
</ul>
