<script lang="ts">
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LeanResults from '$lib/components/LeanResults.svelte';
	import type { Diagnostic } from '$lib/lean/client';

	let code = $state('import Distill\n\nexample : 1 + 1 = 2 := by\n  rfl\n');
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
	let leanEditor = $state<LeanEditor>();
</script>

<svelte:head><title>Lean · Distill</title></svelte:head>

<h1>Lean</h1>

<LeanEditor
	bind:this={leanEditor}
	bind:value={code}
	onstatus={(nextStatus) => (status = nextStatus)}
	ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
/>

<LeanResults
	{status}
	{diagnostics}
	onselect={(line, character) => leanEditor?.goTo(line, character)}
/>
