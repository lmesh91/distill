<script lang="ts">
	import { describeSaveState, type SaveState } from '$lib/levels/autosave';

	let { saveState }: { saveState: SaveState } = $props();

	// Re-render every 15 s so "Saved just now" turns into "Saved 1 minute ago".
	let now = $state(Date.now());
	$effect(() => {
		const interval = setInterval(() => (now = Date.now()), 15_000);
		return () => clearInterval(interval);
	});

	const text = $derived(describeSaveState(saveState, Math.max(now, Date.now())));
</script>

<p class="save-status" class:error={saveState.kind === 'error'} role="status" aria-live="polite">
	{text}
</p>

<style>
	.save-status {
		margin: 0;
		min-width: 9rem;
		font-size: 0.875rem;
		color: #555;
		text-align: right;
		white-space: nowrap;
	}

	.error {
		color: #b42318;
		font-weight: 600;
		white-space: normal;
	}
</style>
