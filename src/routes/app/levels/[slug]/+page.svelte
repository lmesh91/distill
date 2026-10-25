<script lang="ts">
	import { untrack } from 'svelte';
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LevelLayout from '$lib/components/LevelLayout.svelte';
	import type { Diagnostic, LineTranslation } from '$lib/lean/client';
	import type { PageProps } from './$types';

	const severities = ['', 'Error', 'Warning', 'Info', 'Hint'];

	let { data }: PageProps = $props();
	let code = $state(untrack(() => data.initialCode));
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
	let translatedLines = $state<LineTranslation[]>([]);
	let translationError = $state(false);

	// Runs before the editor mounts, including when SvelteKit reuses this page for another slug.
	$effect.pre(() => {
		code = data.initialCode;
		status = 'Connecting…';
		diagnostics = [];
		translatedLines = [];
		translationError = false;
	});
</script>

<svelte:head><title>{data.level.title} · Distill</title></svelte:head>

<LevelLayout title={data.level.title} mode={data.level.type}>
	{#snippet toolbar()}
		{#if data.level.hints.length > 0}
			<button class="hints" type="button">Hints</button>
		{/if}
	{/snippet}

	{#snippet goal()}
		{#if data.level.type === 'guided' && data.level.targetProof}
			<p>Write Lean whose translation matches this proof:</p>
			<blockquote class="target-proof">{data.level.targetProof}</blockquote>
		{:else}
			<p>{data.level.statement}</p>
		{/if}
	{/snippet}

	{#snippet brief()}
		<h2>Description</h2>
		<p>{data.level.description}</p>
	{/snippet}

	{#snippet editor()}
		{#key data.level.id}
			<LeanEditor
				bind:value={code}
				onstatus={(nextStatus) => (status = nextStatus)}
				ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
				ontranslation={(lines) => {
					translationError = lines === null;
					if (lines) translatedLines = lines;
				}}
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

	{#snippet translation()}
		{#if translationError}
			<p role="status">Translation unavailable. Ensure you import Distill as your first line.</p>
		{/if}
		<ol class="translation">
			{#each translatedLines as { english }, index (index)}
				<li><span class="line-number">{index + 1}</span>{english}</li>
			{/each}
		</ol>
	{/snippet}
</LevelLayout>

<style>
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

	.target-proof {
		margin: 0 0 1rem;
		padding-left: 0.75rem;
		border-left: 3px solid #4a4a4a;
		white-space: pre-wrap;
	}

	.translation {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.translation li {
		display: flex;
		gap: 0.75rem;
		margin-bottom: 0.375rem;
	}

	.line-number {
		flex: none;
		min-width: 1.5rem;
		color: #777;
		font-variant-numeric: tabular-nums;
		text-align: right;
	}
</style>
