<script lang="ts">
	import type { Snippet } from 'svelte';
	import { resolve } from '$app/paths';

	let {
		open = $bindable(false),
		title,
		nextLevelSlug,
		onretry,
		details
	}: {
		open?: boolean;
		title: string;
		// the level to offer next, or null when this was the last one on its path
		nextLevelSlug: string | null;
		onretry: () => void;
		// optional extra content, such as the score and reference solution (#118)
		details?: Snippet;
	} = $props();

	const id = $props.id();
	let dialog: HTMLDialogElement;
	let primary = $state<HTMLElement>();

	// a native modal dialog: traps focus, closes on Escape, and returns focus when closed
	$effect(() => {
		if (open && !dialog.open) {
			dialog.showModal();
			primary?.focus();
		} else if (!open && dialog.open) {
			dialog.close();
		}
	});

	function retry() {
		open = false;
		onretry();
	}
</script>

<dialog
	bind:this={dialog}
	class="level-complete"
	aria-labelledby={`${id}-title`}
	onclose={() => (open = false)}
>
	<h2 id={`${id}-title`}>Level complete!</h2>
	<p class="subtitle">You proved <strong>{title}</strong>.</p>

	{@render details?.()}

	{#if !nextLevelSlug}
		<p class="end">That's the last level on this path. Pick another one from the map.</p>
	{/if}

	<div class="actions">
		<button type="button" class="button" onclick={retry}>Retry</button>
		{#if nextLevelSlug}
			<a class="button" href={resolve('/app')}>Back to map</a>
			<a
				class="button primary"
				href={resolve('/app/levels/[slug]', { slug: nextLevelSlug })}
				bind:this={primary}
				onclick={() => (open = false)}
			>
				Next level <span aria-hidden="true">→</span>
			</a>
		{:else}
			<a class="button primary" href={resolve('/app')} bind:this={primary}>Back to map</a>
		{/if}
	</div>
</dialog>

<style>
	.level-complete {
		box-sizing: border-box;
		width: min(30rem, calc(100vw - 2rem));
		padding: 1.75rem;
		border: 2px solid #333;
		border-radius: 10px;
		color: #333;
		text-align: center;
	}

	.level-complete::backdrop {
		background: rgb(0 0 0 / 0.4);
	}

	h2 {
		margin: 0 0 0.5rem;
		font-size: 1.75rem;
	}

	.subtitle,
	.end {
		margin: 0 0 1.25rem;
		color: #555;
		line-height: 1.5;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: 0.75rem;
	}

	.button {
		padding: 0.625rem 1.125rem;
		border: 2px solid #333;
		border-radius: 6px;
		background: #fff;
		color: #333;
		font: inherit;
		font-weight: 600;
		text-decoration: none;
		cursor: pointer;
	}

	.button:hover {
		background: #f3f3f3;
	}

	.button.primary {
		background: #333;
		color: #fff;
	}

	.button.primary:hover {
		background: #4a4a4a;
	}

	.button:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: 2px;
	}
</style>
