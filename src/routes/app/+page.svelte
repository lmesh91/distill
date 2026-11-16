<script lang="ts">
	import { resolve } from '$app/paths';
</script>

<svelte:head><title>Play · Distill</title></svelte:head>

<!-- placeholder until the level select page (#126) -->
<main class="play">
	<h1 class="display">Ready to play?</h1>
	<p class="muted">You are signed in. Levels will show up here soon.</p>
	<a class="button primary" href={resolve('/app/lean')}>Open the Lean sandbox</a>
</main>

<style>
	.play {
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-7) var(--page-gutter);
	}

	h1 {
		margin: 0 0 var(--space-2);
		font-size: var(--text-3xl);
	}

	p {
		margin: 0 0 var(--space-5);
	}
</style>
