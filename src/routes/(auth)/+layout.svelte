<script lang="ts">
	import type { Snippet } from 'svelte';

	let { children }: { children: Snippet } = $props();
</script>

<main class="auth-page">
	{@render children()}
</main>

<style>
	.auth-page {
		display: flex;
		justify-content: center;
		padding: 4rem 1rem;
	}
</style>
