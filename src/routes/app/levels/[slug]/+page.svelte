<script lang="ts">
	import { untrack } from 'svelte';
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LevelLayout from '$lib/components/LevelLayout.svelte';
	import SaveStatus from '$lib/components/SaveStatus.svelte';
	import type { Diagnostic } from '$lib/lean/client';
	import {
		createAutosaver,
		saveLevelCode,
		type Autosaver,
		type SaveState
	} from '$lib/levels/autosave';
	import type { PageProps } from './$types';

	const severities = ['', 'Error', 'Warning', 'Info', 'Hint'];

	let { data }: PageProps = $props();
	let code = $state(untrack(() => data.initialCode));
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
	let saveState = $state<SaveState>({ kind: 'idle' });

	// the code the autosaver last saw, so loading a level's code isn't saved back as an edit
	let lastSeenCode = untrack(() => data.initialCode);
	let autosaver: Autosaver | undefined;

	function loadedSaveState(lastSavedAt: number | null): SaveState {
		return lastSavedAt ? { kind: 'saved', at: lastSavedAt } : { kind: 'idle' };
	}

	// runs before the editor mounts, including when SvelteKit reuses this page for another slug
	$effect.pre(() => {
		code = data.initialCode;
		lastSeenCode = data.initialCode;
		saveState = loadedSaveState(data.lastSavedAt);
		status = 'Connecting…';
		diagnostics = [];
	});

	// one autosaver per level. Its save function is bound to this level's id, so when the user
	// switches levels, the old autosaver flushes any waiting edit to the level it came from
	$effect(() => {
		const levelId = data.level.id;
		const saver = createAutosaver({
			save: (nextCode, savedAt, options) => saveLevelCode(levelId, nextCode, savedAt, options),
			onstate: (state) => {
				if (autosaver === saver) saveState = state;
			}
		});
		autosaver = saver;

		// save right away if the tab is closed, hidden, or reloaded
		const flushOnHide = () => {
			if (document.visibilityState === 'hidden') void saver.flush({ keepalive: true });
		};
		const flushOnPageHide = () => void saver.flush({ keepalive: true });
		document.addEventListener('visibilitychange', flushOnHide);
		window.addEventListener('pagehide', flushOnPageHide);

		return () => {
			document.removeEventListener('visibilitychange', flushOnHide);
			window.removeEventListener('pagehide', flushOnPageHide);
			if (autosaver === saver) autosaver = undefined;
			void saver.dispose();
		};
	});

	// Every edit restarts the 500 ms autosave timer.
	$effect(() => {
		const current = code;
		untrack(() => {
			if (current === lastSeenCode) return;
			lastSeenCode = current;
			autosaver?.schedule(current);
		});
	});
</script>

<svelte:head><title>{data.level.title} · Distill</title></svelte:head>

<LevelLayout title={data.level.title} mode={data.level.type}>
	{#snippet toolbar()}
		<SaveStatus {saveState} />
		{#if data.level.hints.length > 0}
			<button class="hints" type="button">Hints</button>
		{/if}
	{/snippet}

	{#snippet goal()}
		<p>{data.level.statement}</p>
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
