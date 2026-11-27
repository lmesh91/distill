<script lang="ts">
	import { resolve } from '$app/paths';
	import { UserAvatar, useClerkContext } from 'svelte-clerk';
	import type { PageProps } from './$types';

	let { data }: PageProps = $props();
	const clerk = useClerkContext();

	// the stored name comes from the Clerk webhook; Clerk's own copy fills in once it loads
	const name = $derived(
		data.displayName ?? clerk.user?.fullName ?? clerk.user?.username ?? 'Distill learner'
	);
	const memberSince = $derived(
		data.memberSince
			? new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(
					new Date(data.memberSince)
				)
			: null
	);
	const stats = $derived(data.stats);
	const percent = $derived(stats.total > 0 ? (stats.completed / stats.total) * 100 : 0);

	// a short duration like "45s", "3m 05s" or "1h 02m"
	function duration(seconds: number): string {
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		const s = seconds % 60;
		const pad = (n: number) => String(n).padStart(2, '0');
		if (h > 0) return `${h}h ${pad(m)}m`;
		if (m > 0) return `${m}m ${pad(s)}s`;
		return `${s}s`;
	}

	const dateFormat = new Intl.DateTimeFormat('en-US', { month: 'short', day: 'numeric' });
</script>

<svelte:head><title>{name} · Distill</title></svelte:head>

<main class="profile">
	<header class="card who">
		<span class="avatar" aria-hidden="true"><UserAvatar /></span>
		<div>
			<h1 class="display">{name}</h1>
			{#if memberSince}<p class="muted">Learning with Distill since {memberSince}</p>{/if}
		</div>
		<a class="button small" href={resolve('/app/account/[...rest]', { rest: '' })}>
			Account settings
		</a>
	</header>

	<section aria-labelledby="stats-title">
		<h2 id="stats-title">Progress</h2>
		<dl class="stats">
			<div class="card">
				<dt>Levels completed</dt>
				<dd>{stats.completed} <span class="of">of {stats.total}</span></dd>
				<div class="meter" aria-hidden="true">
					<div class="meter-fill" style:width={`${percent}%`}></div>
				</div>
			</div>
			<div class="card">
				<dt>In progress</dt>
				<dd>{stats.inProgress}</dd>
			</div>
			<div class="card">
				<dt>Proof checks</dt>
				<dd>{stats.checks}</dd>
			</div>
			<div class="card">
				<dt>Attempts per level</dt>
				<dd>{stats.averageAttempts ?? '—'}</dd>
			</div>
		</dl>
	</section>

	<section aria-labelledby="solves-title">
		<h2 id="solves-title">Completed levels</h2>
		{#if stats.solves.length === 0}
			<p class="card empty">
				Nothing completed yet. <a href={resolve('/app')}>Pick a level</a> to get started.
			</p>
		{:else}
			<div class="table-wrap card">
				<table>
					<thead>
						<tr>
							<th scope="col">Level</th>
							<th scope="col">Attempts</th>
							<th scope="col">Time</th>
							<th scope="col">Completed</th>
						</tr>
					</thead>
					<tbody>
						{#each stats.solves as solve (solve.slug)}
							<tr>
								<th scope="row">
									<a href={resolve('/app/levels/[slug]', { slug: solve.slug })}>{solve.title}</a>
								</th>
								<td>{solve.attempts ?? '—'}</td>
								<td>{solve.seconds === null ? '—' : duration(solve.seconds)}</td>
								<td>{dateFormat.format(new Date(solve.completedAt))}</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		{/if}
	</section>
</main>

<style>
	.profile {
		display: grid;
		/* minmax(0, …) lets the table scroll inside its card instead of widening the page */
		grid-template-columns: minmax(0, 1fr);
		gap: var(--space-6);
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-7) var(--page-gutter) var(--space-8);
	}

	.who {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-4);
	}

	.who > div {
		flex: 1 1 14rem;
		min-width: 0;
	}

	/* Clerk's avatar draws once Clerk loads; the box keeps the header from shifting */
	.avatar {
		display: grid;
		place-items: center;
		width: 4rem;
		height: 4rem;
		overflow: hidden;
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface-sunken);
	}

	.avatar :global(img),
	.avatar :global(.cl-avatarBox) {
		width: 100%;
		height: 100%;
		border-radius: 0;
	}

	h1 {
		margin: 0;
		font-size: var(--text-3xl);
		overflow-wrap: anywhere;
	}

	h2 {
		margin: 0 0 var(--space-3);
		font-size: var(--text-xl);
	}

	p {
		margin: 0;
	}

	.stats {
		display: grid;
		grid-template-columns: repeat(auto-fit, minmax(11rem, 1fr));
		gap: var(--space-3);
		margin: 0;
	}

	dt {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		font-weight: var(--weight-bold);
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	dd {
		margin: var(--space-1) 0 0;
		font-family: var(--font-display);
		font-size: var(--text-3xl);
		line-height: 1;
	}

	.of {
		color: var(--color-text-muted);
		font-size: var(--text-xl);
	}

	.meter {
		height: 0.625rem;
		margin-top: var(--space-2);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-sm);
		background: var(--color-surface-sunken);
		overflow: hidden;
	}

	.meter-fill {
		height: 100%;
		background: var(--color-success);
	}

	.table-wrap {
		padding: 0;
		overflow-x: auto;
	}

	table {
		width: 100%;
		border-collapse: collapse;
	}

	th,
	td {
		padding: var(--space-2) var(--space-4);
		border-bottom: 1px solid var(--color-border-subtle);
		text-align: left;
		white-space: nowrap;
	}

	tbody tr:last-child > * {
		border-bottom: 0;
	}

	thead th {
		color: var(--color-text-muted);
		font-size: var(--text-xs);
		text-transform: uppercase;
		letter-spacing: 0.06em;
	}

	tbody th {
		font-weight: var(--weight-bold);
		white-space: normal;
	}

	td {
		font-variant-numeric: tabular-nums;
	}
</style>
