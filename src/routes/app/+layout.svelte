<script lang="ts">
	import { onMount, type Snippet } from 'svelte';
	import { getMusicPlayer } from '$lib/audio/player';

	let { children }: { children: Snippet } = $props();

	// the concentration loop (#175) plays on every game page and stops when the user leaves them
	onMount(() => {
		const music = getMusicPlayer();
		music.enter('concentration');
		return () => music.leave('concentration');
	});
</script>

{@render children()}
