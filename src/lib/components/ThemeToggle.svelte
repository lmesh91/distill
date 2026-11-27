<script lang="ts">
	import { onMount } from 'svelte';
	import { currentTheme, setTheme, type Theme } from '$lib/theme';

	// null until mounted, since the server can't know the visitor's theme
	let theme = $state<Theme | null>(null);

	onMount(() => {
		theme = currentTheme();
		// keep the icon right if the system setting changes and nothing was picked
		const media = matchMedia('(prefers-color-scheme: dark)');
		const follow = () => (theme = currentTheme());
		media.addEventListener('change', follow);
		return () => media.removeEventListener('change', follow);
	});

	function toggle() {
		const next = theme === 'dark' ? 'light' : 'dark';
		setTheme(next);
		theme = next;
	}

	const label = $derived(theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme');
</script>

<button
	class="theme-toggle button ghost small"
	type="button"
	onclick={toggle}
	aria-label={label}
	title={label}
	disabled={theme === null}
>
	<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true">
		{#if theme === 'dark'}
			<!-- a pixel sun: shown in dark mode, switches to light -->
			<path
				d="M7 1h2v2H7zM7 13h2v2H7zM1 7h2v2H1zM13 7h2v2h-2zM3 3h2v2H3zM11 3h2v2h-2zM3 11h2v2H3zM11 11h2v2h-2zM6 5h4v1h1v4h-1v1H6v-1H5V6h1z"
			/>
		{:else}
			<!-- a pixel moon: shown in light mode, switches to dark -->
			<path d="M6 2h4v1H8v1H7v2H6v4h1v2h1v1h2v1H6v-1H4v-1H3V9H2V6h1V4h1V3h2z" />
		{/if}
	</svg>
</button>

<style>
	.theme-toggle {
		min-width: 2rem;
		padding-inline: var(--space-2);
	}

	svg {
		fill: currentColor;
		shape-rendering: crispEdges;
	}
</style>
