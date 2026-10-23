<script lang="ts">
	import { untrack } from 'svelte';
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LevelLayout from '$lib/components/LevelLayout.svelte';
	import LeanResults from '$lib/components/LeanResults.svelte';
	import LevelComplete from '$lib/components/LevelComplete.svelte';
	import { resolve } from '$app/paths';
	import SaveStatus from '$lib/components/SaveStatus.svelte';
	import type { Diagnostic } from '$lib/lean/client';
	import {
		createAutosaver,
		saveLevelCode,
		type Autosaver,
		type SaveState
	} from '$lib/levels/autosave';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let code = $state(untrack(() => data.initialCode));
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
	let leanEditor = $state<LeanEditor>();
	// opens the post-completion dialog. The Check proof flow (#56) sets this to true once a
	// submission is accepted
	let showCompletion = $state(false);
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
		showCompletion = false;
	});

	// starts the level over from its starter code
	function retry() {
		code = data.level.starterCode;
		leanEditor?.goTo(0, 0);
	}

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

	// every edit restarts the 500 ms autosave timer
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
		{#if data.completed}
			<div class="completed" role="note">
				<p><span aria-hidden="true">✓</span> You've completed this level.</p>
				{#if data.nextLevelSlug}
					<a href={resolve('/app/levels/[slug]', { slug: data.nextLevelSlug })}>
						Next level <span aria-hidden="true">→</span>
					</a>
				{/if}
			</div>
		{/if}

		<h2>Description</h2>
		<p>{data.level.description}</p>
	{/snippet}

	{#snippet editor()}
		{#key data.level.id}
			<LeanEditor
				bind:this={leanEditor}
				bind:value={code}
				onstatus={(nextStatus) => (status = nextStatus)}
				ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
			/>
		{/key}
	{/snippet}

	{#snippet output()}
		<LeanResults
			{status}
			{diagnostics}
			onselect={(line, character) => leanEditor?.goTo(line, character)}
		/>
	{/snippet}
</LevelLayout>

<LevelComplete
	bind:open={showCompletion}
	title={data.level.title}
	nextLevelSlug={data.nextLevelSlug}
	onretry={retry}
/>

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

	.completed {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: 0.5rem 1rem;
		margin: 0 0 1rem;
		padding: 0.5rem 0.75rem;
		border: 1px solid #1a7f37;
		border-radius: 6px;
		background: #eef8f0;
		color: #1a5e2b;
		font-size: 0.875rem;
	}

	.completed p {
		margin: 0;
		font-weight: 600;
	}

	.completed a {
		color: #1a5e2b;
		font-weight: 600;
	}

	.completed a:focus-visible,
	.hints:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: 2px;
	}
</style>
