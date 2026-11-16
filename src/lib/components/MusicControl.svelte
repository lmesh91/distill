<script lang="ts">
	import { onMount } from 'svelte';
	import { getMusicPlayer } from '$lib/audio/player';
	import { defaultMusicSettings, type MusicPlayer, type MusicState } from '$lib/audio/music';

	// null until mounted, since the server can't know the visitor's saved settings
	let player = $state<MusicPlayer | null>(null);
	let music = $state<MusicState | null>(null);

	onMount(() => {
		player = getMusicPlayer();
		return player.subscribe((next) => (music = next));
	});

	const silent = $derived(!music || music.muted || music.volume === 0);
	const label = $derived(silent ? 'Turn music on' : 'Mute music');
	const percent = $derived(Math.round((music?.volume ?? 0) * 100));

	// unmuting at zero volume would still be silent, so go back to the default level instead
	function turnOn() {
		if (music?.volume === 0) player?.setVolume(defaultMusicSettings.volume);
		else player?.setMuted(false);
	}
</script>

<div class="music" role="group" aria-label="Background music">
	<button
		class="button ghost small"
		type="button"
		onclick={() => (silent ? turnOn() : player?.setMuted(true))}
		aria-label={label}
		title={music?.waitingForGesture ? 'Music starts when you click or press a key' : label}
		disabled={!player}
	>
		<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
			<!-- a pixel speaker -->
			<path d="M1 6h3v4H1zM4 5h1v6H4zM5 4h1v8H5zM6 3h1v10H6zM7 2h1v12H7z" />
			{#if silent}
				<!-- an x for muted -->
				<path
					d="M10 5h1v1h-1zM11 6h1v1h-1zM12 7h1v2h-1zM11 9h1v1h-1zM10 10h1v1h-1zM13 6h1v1h-1zM14 5h1v1h-1zM13 9h1v1h-1zM14 10h1v1h-1z"
				/>
			{:else}
				<!-- sound waves -->
				<path d="M10 6h1v4h-1zM12 4h1v1h-1zM13 5h1v6h-1zM12 11h1v1h-1z" />
			{/if}
		</svg>
	</button>
	<input
		class="volume"
		type="range"
		min="0"
		max="100"
		step="5"
		value={silent ? 0 : percent}
		oninput={(event) => player?.setVolume(event.currentTarget.valueAsNumber / 100)}
		aria-label="Music volume"
		aria-valuetext={silent ? 'muted' : `${percent}%`}
		disabled={!player}
	/>
</div>

<style>
	.music {
		display: flex;
		align-items: center;
		gap: var(--space-1);
	}

	.button {
		min-width: 2rem;
		padding-inline: var(--space-2);
	}

	svg {
		fill: currentColor;
	}

	.volume {
		width: 5.5rem;
		accent-color: var(--color-brand);
		cursor: pointer;
	}

	.volume:disabled {
		cursor: default;
	}

	/* on small screens only the mute button fits next to the other controls */
	@media (max-width: 36rem) {
		.volume {
			display: none;
		}
	}
</style>
