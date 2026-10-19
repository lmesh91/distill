<script lang="ts">
	import { untrack } from 'svelte';
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import type { Diagnostic } from '$lib/lean/client';
	import type { PageProps } from './$types';

	const severities = ['', 'Error', 'Warning', 'Info', 'Hint'];

	let { data }: PageProps = $props();
	let code = $state(untrack(() => data.initialCode));
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);

	// Runs before the editor mounts, including when SvelteKit reuses this page for another slug.
	$effect.pre(() => {
		code = data.initialCode;
		status = 'Connecting…';
		diagnostics = [];
	});
</script>

<svelte:head><title>{data.level.title} · Distill</title></svelte:head>

<h1>{data.level.title}</h1>

<p>{data.level.statement}</p>
<p>{data.level.description}</p>

<p>Connection Status: <span role="status">{status}</span></p>

{#key data.level.id}
	<LeanEditor
		bind:value={code}
		onstatus={(nextStatus) => (status = nextStatus)}
		ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
	/>
{/key}

<ul>
	{#each diagnostics as diagnostic, index (index)}
		<li>
			{severities[diagnostic.severity]} at line {diagnostic.range.start.line + 1}, column
			{diagnostic.range.start.character + 1}:
			<pre>{diagnostic.message}</pre>
		</li>
	{/each}
</ul>
