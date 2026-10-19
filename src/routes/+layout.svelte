<script lang="ts">
	import type { Snippet } from 'svelte';
	import { ClerkProvider } from 'svelte-clerk';
	import SiteNav from '$lib/components/SiteNav.svelte';

	let { children }: { children: Snippet } = $props();
</script>

<ClerkProvider>
	<div class="app">
		<SiteNav />
		<div class="page">
			{@render children()}
		</div>
	</div>
</ClerkProvider>

<style>
	:global(body) {
		margin: 0;
	}

	.app {
		display: grid;
		grid-template-rows: auto minmax(0, 1fr);
		min-height: 100dvh;
	}
</style>
