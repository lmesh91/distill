<script lang="ts">
	import { onDestroy, onMount, untrack } from 'svelte';
	import { navigating } from '$app/state';
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LevelLayout from '$lib/components/LevelLayout.svelte';
	import LeanResults from '$lib/components/LeanResults.svelte';
	import SaveStatus from '$lib/components/SaveStatus.svelte';
	import ProofCheckStatus from '$lib/components/ProofCheckStatus.svelte';
	import { createProofChecker, type ProofCheckState } from '$lib/levels/proofCheck';
	import type { Diagnostic } from '$lib/lean/client';
	import {
		createAutosaver,
		saveLevelCode,
		syncClock,
		type Autosaver,
		type SaveState
	} from '$lib/levels/autosave';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	let code = $state(untrack(() => data.initialCode));
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
	let leanEditor = $state<LeanEditor>();
	let saveState = $state<SaveState>({ kind: 'idle' });
	// true while SvelteKit loads another level and its saved code
	const loadingLevel = $derived(navigating.to?.route.id === '/app/levels/[slug]');
	let check = $state<ProofCheckState>({ kind: 'idle' });
	const checker = createProofChecker({ onstate: (next) => (check = next) });
	const checking = $derived(check.kind === 'waiting' || check.kind === 'running');
	const canCheck = $derived(!loadingLevel && !checking && code.trim().length > 0);

	function checkProof() {
		if (!canCheck || checker.checking) return;
		void checker.check(data.level.slug, code);
	}

	onDestroy(() => checker.cancel());

	// the code the autosaver last saw, so loading a level's code isn't saved back as an edit
	let lastSeenCode = untrack(() => data.initialCode);
	let autosaver: Autosaver | undefined;
	// autosavers for levels the user already left that still have code to save
	const leaving = new Set<Autosaver>();
	const allSavers = () => [...(autosaver ? [autosaver] : []), ...leaving];

	function loadedSaveState(lastSavedAt: number | null): SaveState {
		return lastSavedAt ? { kind: 'saved', at: lastSavedAt } : { kind: 'idle' };
	}

	// runs before the editor mounts, including when SvelteKit reuses this page for another slug
	$effect.pre(() => {
		syncClock(data.serverNow);
		code = data.initialCode;
		lastSeenCode = data.initialCode;
		saveState = loadedSaveState(data.lastSavedAt);
		status = 'Connecting…';
		diagnostics = [];
		checker.cancel();
	});

	// one autosaver per level. Its save function is bound to this level's id, so when the user
	// switches levels, the old autosaver flushes any waiting edit to the level it came from
	$effect(() => {
		const levelId = data.level.id;
		const saver = createAutosaver({
			save: (nextCode, savedAt, options) => saveLevelCode(levelId, nextCode, savedAt, options),
			onstate: (state) => {
				if (autosaver === saver) saveState = state;
				else if (!saver.hasUnsaved) leaving.delete(saver);
			}
		});
		autosaver = saver;

		return () => {
			if (autosaver === saver) autosaver = undefined;
			// keep it until its code is stored, so a failed save while switching levels still
			// retries and still counts when the tab closes
			leaving.add(saver);
			void saver.dispose().then(() => {
				if (!saver.hasUnsaved) leaving.delete(saver);
			});
		};
	});

	onMount(() => {
		// save right away if the tab is closed, hidden, or reloaded, including levels just left
		const flushAll = () => {
			for (const saver of allSavers()) void saver.flush({ keepalive: true });
		};
		const flushOnHide = () => {
			if (document.visibilityState === 'hidden') flushAll();
		};
		// ask before closing if some code isn't stored yet (e.g. a failed or in-progress save)
		const warnIfUnsaved = (event: BeforeUnloadEvent) => {
			if (allSavers().some((saver) => saver.hasUnsaved)) event.preventDefault();
		};
		document.addEventListener('visibilitychange', flushOnHide);
		window.addEventListener('pagehide', flushAll);
		window.addEventListener('beforeunload', warnIfUnsaved);
		return () => {
			document.removeEventListener('visibilitychange', flushOnHide);
			window.removeEventListener('pagehide', flushAll);
			window.removeEventListener('beforeunload', warnIfUnsaved);
		};
	});

	// every edit restarts the 500 ms autosave timer
	$effect(() => {
		const current = code;
		untrack(() => {
			if (current === lastSeenCode) return;
			lastSeenCode = current;
			// A verdict applies only to the submitted text, including while waiting for Lean.
			checker.cancel();
			autosaver?.schedule(current);
		});
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
	<p>When you’re ready, select Check proof to verify that your proof solves the level’s goal.</p>
{/snippet}

<LevelLayout title={data.level.title} help={proofHelp}>
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
				bind:this={leanEditor}
				bind:value={code}
				onstatus={(nextStatus) => (status = nextStatus)}
				ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
			>
				{#snippet titleBar()}
					<SaveStatus {saveState} loading={loadingLevel} />
				{/snippet}
			</LeanEditor>
		{/key}
	{/snippet}

	{#snippet actions()}
		<button class="check-proof" type="button" disabled={!canCheck} onclick={checkProof}>
			Check proof
		</button>
		<ProofCheckStatus {check} />
	{/snippet}

	{#snippet output()}
		<LeanResults
			{status}
			{diagnostics}
			onselect={(line, character) => leanEditor?.goTo(line, character)}
		/>
	{/snippet}
</LevelLayout>

<style>
	.check-proof {
		padding: 0.5rem 1rem;
		border: 2px solid var(--color-border, #1b1b1f);
		border-radius: var(--radius, 6px);
		background: var(--color-brand, #1a6db8);
		color: #fff;
		font: inherit;
		font-weight: var(--weight-bold, 650);
		cursor: pointer;
	}

	.check-proof:not(:disabled):hover {
		filter: brightness(0.9);
	}

	.check-proof:disabled {
		opacity: 0.5;
		cursor: not-allowed;
	}

	.check-proof:focus-visible {
		outline: 2px solid var(--color-brand, #1a6db8);
		outline-offset: 2px;
	}

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
