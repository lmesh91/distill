<script lang="ts">
	import { untrack } from 'svelte';
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LevelLayout from '$lib/components/LevelLayout.svelte';
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

{#snippet proofHelp()}
	<h2>Build your proof</h2>
	<p>
		Write a Lean proof of the target statement in the editor. Replace any
		<code>sorry</code> placeholders with your own proof steps. Lean checks your code as you type; use
		the Lean output to work through errors and unfinished goals.
	</p>
{/snippet}

<LevelLayout
	title={data.level.title}
	help={data.level.type === 'from-scratch' ? proofHelp : undefined}
>
	{#snippet toolbar()}
		{#if data.level.type !== 'from-scratch' && data.level.hints.length > 0}
			<button class="hints" type="button">Hints</button>
		{/if}
	{/snippet}

	{#snippet goal()}
		<p class="statement">{data.level.statement}</p>
	{/snippet}

	{#snippet brief()}
		<h2>Description</h2>
		<p class="description">{data.level.description}</p>
	{/snippet}

	{#snippet editor()}
		{#key data.level.id}
			<LeanEditor
				bind:value={code}
				onstatus={(nextStatus) => (status = nextStatus)}
				ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
			/>
		{/key}
	{/snippet}

	{#snippet output()}
		<p>Connection Status: <span role="status">{status}</span></p>

		<ul>
			{#each diagnostics as diagnostic, index (index)}
				<li>
					{severities[diagnostic.severity]} at line {diagnostic.range.start.line + 1}, column
					{diagnostic.range.start.character + 1}:
					<pre>{diagnostic.message}</pre>
				</li>
			{/each}
		</ul>
	{/snippet}
</LevelLayout>

<style>
	.statement,
	.description {
		white-space: pre-wrap;
		overflow-wrap: anywhere;
	}

	.hints {
		padding: 0.375rem 1rem;
		border: 1px solid #4a4a4a;
		border-radius: 6px;
		background: #fff;
		color: #333;
		font: inherit;
		cursor: pointer;
	}

	.hints:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: 2px;
	}
</style>
