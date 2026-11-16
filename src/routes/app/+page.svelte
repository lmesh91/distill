<script lang="ts">
	import { resolve } from '$app/paths';
	import type { LevelType } from '$lib/types/level';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();

	// the names and colors match the modes on the home page
	const modes: Record<LevelType, { label: string; accent: string }> = {
		guided: { label: 'Guided', accent: 'mint' },
		hints: { label: 'Hints', accent: 'highlight' },
		'from-scratch': { label: 'From scratch', accent: 'pink' }
	};

	const total = $derived(data.levels.length);
	const completed = $derived(data.levels.filter((level) => level.status === 'completed').length);
	const started = $derived(data.levels.some((level) => level.status !== 'not_started'));
</script>

<svelte:head><title>Levels · Distill</title></svelte:head>

<main class="play">
	<header class="intro">
		<div>
			<h1 class="display">Levels</h1>
			{#if total > 0}
				<p class="muted">{completed} of {total} completed</p>
				<div class="meter" aria-hidden="true">
					<div class="meter-fill" style:width={`${(completed / total) * 100}%`}></div>
				</div>
			{/if}
		</div>
		<div class="actions">
			{#if data.continueSlug}
				<a class="button primary" href={resolve('/app/levels/[slug]', { slug: data.continueSlug })}>
					{started ? 'Continue' : 'Start the first level'}
				</a>
			{/if}
			<a class="button" href={resolve('/app/lean')}>Open the sandbox</a>
		</div>
	</header>

	{#if total === 0}
		<p class="card empty">No levels are published yet. The sandbox is open in the meantime.</p>
	{:else}
		{#if !data.continueSlug}
			<p class="card done">
				<span class="highlight">You finished every level.</span> More are on the way.
			</p>
		{/if}

		<ol class="level-list">
			{#each data.levels as level (level.slug)}
				{@const mode = modes[level.type]}
				<li>
					<a
						class="level"
						class:completed={level.status === 'completed'}
						href={resolve('/app/levels/[slug]', { slug: level.slug })}
					>
						<span class="number" aria-hidden="true">{level.number}</span>
						<span class="title">
							<span class="sr-only">Level {level.number}:</span>
							{level.title}
						</span>
						{#if mode}
							<span class="mode" style:--accent={`var(--color-${mode.accent})`}>
								{mode.label}
							</span>
						{/if}
						<span class="status">
							{#if level.status === 'completed'}
								<span class="check" title="Completed">
									<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
										<!-- a pixel checkmark -->
										<path
											d="M1 7h2v2H1zM3 9h2v2H3zM5 11h2v2H5zM7 9h2v2H7zM9 7h2v2H9zM11 5h2v2h-2zM13 3h2v2h-2z"
										/>
									</svg>
									<span class="sr-only">Completed</span>
								</span>
							{:else if level.status === 'in_progress'}
								<span class="badge">In progress</span>
							{/if}
						</span>
					</a>
				</li>
			{/each}
		</ol>
	{/if}
</main>

<style>
	.play {
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-7) var(--page-gutter) var(--space-8);
	}

	.intro {
		display: flex;
		flex-wrap: wrap;
		align-items: flex-end;
		justify-content: space-between;
		gap: var(--space-4) var(--space-6);
		margin-bottom: var(--space-6);
	}

	h1 {
		margin: 0 0 var(--space-2);
		font-size: var(--text-3xl);
	}

	.intro p {
		margin: 0 0 var(--space-2);
	}

	/* a chunky pixel progress bar */
	.meter {
		width: min(20rem, 70vw);
		height: 0.75rem;
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-sm);
		background: var(--color-surface);
		overflow: hidden;
	}

	.meter-fill {
		height: 100%;
		background: var(--color-success);
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.empty,
	.done {
		margin: 0 0 var(--space-5);
	}

	.level-list {
		display: grid;
		gap: var(--space-3);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.level {
		display: grid;
		grid-template-columns: auto minmax(0, 1fr) auto 6.5rem;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-3) var(--space-4);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-pixel-sm);
		color: var(--color-ink);
		text-decoration: none;
		transition:
			transform var(--duration-fast) var(--ease-out),
			box-shadow var(--duration-fast) var(--ease-out);
	}

	.level:hover {
		transform: translate(-1px, -1px);
		box-shadow: var(--shadow-pixel);
	}

	.number {
		display: grid;
		place-items: center;
		width: 2.25rem;
		height: 2.25rem;
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-sm);
		background: var(--color-surface-sunken);
		font-family: var(--font-display);
		font-size: var(--text-xl);
		line-height: 1;
	}

	.completed .number {
		background: var(--color-success-soft);
	}

	.title {
		font-weight: var(--weight-bold);
		overflow-wrap: anywhere;
	}

	.mode {
		padding: 0 var(--space-2);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-sm);
		background: var(--accent);
		color: var(--color-on-highlight);
		font-size: var(--text-xs);
		font-weight: var(--weight-bold);
		line-height: 1.6;
		white-space: nowrap;
	}

	.status {
		display: flex;
		justify-content: flex-end;
	}

	.check {
		display: grid;
		place-items: center;
		width: 1.75rem;
		height: 1.75rem;
		border-radius: var(--radius-sm);
		background: var(--color-success);
		color: var(--color-on-status);
	}

	.check svg {
		fill: currentColor;
	}

	.status .badge {
		white-space: nowrap;
	}

	@media (max-width: 36rem) {
		.level {
			grid-template-columns: auto minmax(0, 1fr) auto;
		}

		/* the mode tag drops under the title so the title keeps its room */
		.mode {
			grid-column: 2;
			grid-row: 2;
			justify-self: start;
		}
	}
</style>
