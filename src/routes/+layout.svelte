<script lang="ts">
	import type { Snippet } from 'svelte';
	import { ClerkProvider } from 'svelte-clerk';
	import '@fontsource/jersey-10';
	import '@fontsource-variable/space-grotesk';
	import '@fontsource-variable/source-serif-4';
	import '$lib/styles/global.css';
	import SiteNav from '$lib/components/SiteNav.svelte';
	import { clerkAppearance } from '$lib/styles/clerk';

	let { children }: { children: Snippet } = $props();
</script>

<!-- signing out from the account menu returns to the signed-out home page -->
<ClerkProvider appearance={clerkAppearance} afterSignOutUrl="/">
	<div class="app">
		<SiteNav />
		<div class="page">
			{@render children()}
		</div>
	</div>
</ClerkProvider>

<style>
	.app {
		display: grid;
		grid-template-rows: auto minmax(0, 1fr);
		min-height: 100dvh;
	}
</style>
