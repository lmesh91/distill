<script lang="ts">
	import { untrack } from 'svelte';
	import { describeSaveState, type SaveState } from '$lib/levels/autosave';

	let { saveState, loading = false }: { saveState: SaveState; loading?: boolean } = $props();

	// the last successful save, so the time stays visible while saving or after an error.
	// the level page remounts this for each level, so it never carries over between levels
	let lastSavedAt = $state(untrack(() => (saveState.kind === 'saved' ? saveState.at : null)));
	$effect(() => {
		if (saveState.kind === 'saved') lastSavedAt = saveState.at;
	});

	// re-render every 15 s so "just now" turns into "1 min ago"
	let now = $state(Date.now());
	$effect(() => {
		const interval = setInterval(() => (now = Date.now()), 15_000);
		return () => clearInterval(interval);
	});

	const indicator = $derived(
		describeSaveState(saveState, lastSavedAt, Math.max(now, Date.now()), loading)
	);
</script>

<div class="save-status {indicator.icon}" title={indicator.label}>
	<svg class="icon" viewBox="0 0 16 16" width="14" height="14" aria-hidden="true">
		{#if indicator.icon === 'saving'}
			<circle class="track" cx="8" cy="8" r="6" />
			<path class="arc" d="M8 2 a6 6 0 0 1 6 6" />
		{:else if indicator.icon === 'saved'}
			<path d="M3 8.5 6.5 12 13 4.5" />
		{:else if indicator.icon === 'error'}
			<circle class="badge" cx="8" cy="8" r="7" />
			<path class="mark" d="M8 4v5" />
			<circle class="dot" cx="8" cy="11.75" r="1" />
		{:else}
			<path d="M4 8h8" />
		{/if}
	</svg>
	{#if indicator.time}
		<span class="time" aria-hidden="true">{indicator.time}</span>
	{/if}
	<!-- screen readers get the full sentence; the icon and short time are visual only -->
	<span class="sr-only" role="status" aria-live="polite">{indicator.label}</span>
</div>

<style>
	.save-status {
		display: inline-flex;
		flex: none;
		align-items: center;
		gap: 6px;
		min-width: 0;
		color: #767676;
		font:
			400 12px / 1.4 system-ui,
			sans-serif;
		white-space: nowrap;
	}

	.icon {
		flex: none;
		fill: none;
		stroke: currentColor;
		stroke-width: 2;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	.saving .icon {
		color: #555;
		animation: spin 0.8s linear infinite;
	}

	.saving .track {
		opacity: 0.25;
	}

	.saved .icon {
		color: #1a7f37;
	}

	.error {
		color: #b42318;
	}

	.error .badge,
	.error .dot {
		fill: currentColor;
		stroke: none;
	}

	.error .mark {
		stroke: #fff;
	}

	.time {
		overflow: hidden;
		text-overflow: ellipsis;
	}

	.sr-only {
		position: absolute;
		width: 1px;
		height: 1px;
		padding: 0;
		overflow: hidden;
		clip-path: inset(50%);
		white-space: nowrap;
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	/* no spinning for people who turn off animations; a slow pulse still shows it's busy */
	@media (prefers-reduced-motion: reduce) {
		.saving .icon {
			animation: pulse 1.6s ease-in-out infinite;
		}

		@keyframes pulse {
			50% {
				opacity: 0.4;
			}
		}
	}
</style>
