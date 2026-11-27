<script lang="ts">
	import { onDestroy, onMount, untrack } from 'svelte';
	import { navigating } from '$app/state';
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LevelLayout from '$lib/components/LevelLayout.svelte';
	import LeanResults from '$lib/components/LeanResults.svelte';
	import LevelComplete from '$lib/components/LevelComplete.svelte';
	import { resolve } from '$app/paths';
	import RichText from '$lib/components/RichText.svelte';
	import SaveStatus from '$lib/components/SaveStatus.svelte';
	import ProofCheckStatus from '$lib/components/ProofCheckStatus.svelte';
	import { createProofChecker, type ProofCheckState } from '$lib/levels/proofCheck';
	import { formatDuration, levelScore, type LevelScore } from '$lib/levels/score';
	import type { Diagnostic, LineTranslation } from '$lib/lean/client';
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
	let translatedLines = $state<LineTranslation[]>([]);
	let translationError = $state(false);
	let leanEditor = $state<LeanEditor>();
	// the post-completion dialog, opened when a proof check is accepted
	let showCompletion = $state(false);
	// set once a check is accepted here, so the completed note shows without reloading the page
	let solvedNow = $state(false);
	// the score from the accepted check, shown in the completion dialog
	let score = $state<LevelScore | null>(null);
	const completed = $derived(data.completed || solvedNow);
	let saveState = $state<SaveState>({ kind: 'idle' });
	// true while SvelteKit loads another level and its saved code
	const loadingLevel = $derived(navigating.to?.route.id === '/app/levels/[slug]');
	let check = $state<ProofCheckState>({ kind: 'idle' });
	const checker = createProofChecker({
		onstate: (next) => {
			check = next;
			if (next.kind === 'accepted') {
				score = levelScore(next.result.progress);
				solvedNow = true;
				showCompletion = true;
			}
		}
	});
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
		translatedLines = [];
		translationError = false;
		showCompletion = false;
		solvedNow = false;
		score = null;
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
			<button class="button small" type="button">Hints</button>
		{/if}
	{/snippet}

	{#snippet goal()}
		{#if data.level.type === 'guided' && data.level.targetProof}
			<p>Write Lean whose translation matches this proof:</p>
			<blockquote class="target-proof"><RichText text={data.level.targetProof} /></blockquote>
		{:else}
			<div class="statement"><RichText text={data.level.statement} /></div>
		{/if}
	{/snippet}

	{#snippet brief()}
		{#if completed}
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
		<div class="description"><RichText text={data.level.description} /></div>
	{/snippet}

	{#snippet editor()}
		{#key data.level.id}
			<LeanEditor
				bind:this={leanEditor}
				bind:value={code}
				lockedLines={data.lockedLines}
				onstatus={(nextStatus) => (status = nextStatus)}
				ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
				ontranslation={(lines) => {
					translationError = lines === null;
					translatedLines = lines ?? [];
				}}
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

	{#snippet translation()}
		{#if translationError}
			<p role="status">Translation unavailable. Ensure you import Distill as your first line.</p>
		{/if}
		<ol class="translation">
			{#each translatedLines as { line, english }, index (index)}
				<li>
					<span class="line-number">{line + 1}</span><span class="english"
						><RichText parts={english} /></span
					>
				</li>
			{/each}
		</ol>
	{/snippet}
</LevelLayout>

<LevelComplete
	bind:open={showCompletion}
	title={data.level.title}
	nextLevelSlug={data.nextLevelSlug}
	onretry={retry}
>
	{#snippet details()}
		{#if score && (score.attempts !== null || score.seconds !== null)}
			<dl class="score">
				{#if score.attempts !== null}
					<div>
						<dt>Attempts</dt>
						<dd>{score.attempts}</dd>
					</div>
				{/if}
				{#if score.seconds !== null}
					<div>
						<dt>Time</dt>
						<dd>{formatDuration(score.seconds)}</dd>
					</div>
				{/if}
			</dl>
		{/if}
	{/snippet}
</LevelComplete>

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
		margin: 1em 0;
		white-space: pre-wrap;
		overflow-wrap: anywhere;
	}

	/* the score in the completion dialog: one tile per stat */
	.score {
		display: flex;
		justify-content: center;
		gap: var(--space-3);
		margin: 0 0 var(--space-5);
	}

	.score div {
		min-width: 6.5rem;
		padding: var(--space-2) var(--space-3);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface-sunken);
	}

	.score dt {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		font-weight: var(--weight-bold);
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	.score dd {
		margin: 0;
		font-family: var(--font-display);
		font-size: var(--text-2xl);
		line-height: 1.1;
	}

	.completed {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		justify-content: space-between;
		gap: var(--space-2) var(--space-4);
		margin: 0 0 var(--space-4);
		padding: var(--space-2) var(--space-3);
		border: var(--border-width) solid var(--color-success);
		border-radius: var(--radius);
		background: var(--color-success-soft);
		color: var(--color-text);
		font-size: var(--text-sm);
	}

	.completed p {
		margin: 0;
		font-weight: var(--weight-bold);
	}

	.completed a {
		color: inherit;
		font-weight: var(--weight-bold);
	}

	.target-proof {
		margin: 0 0 var(--space-4);
		padding-left: var(--space-3);
		border-left: 3px solid var(--color-border);
		white-space: pre-wrap;
	}

	.translation {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.translation li {
		display: flex;
		gap: var(--space-3);
		margin-bottom: var(--space-2);
	}

	.line-number {
		flex: none;
		min-width: 1.5rem;
		color: var(--color-text-subtle);
		font-family: var(--font-body);
		font-variant-numeric: tabular-nums;
		text-align: right;
	}

	.english {
		min-width: 0;
		overflow-wrap: anywhere;
	}
</style>
