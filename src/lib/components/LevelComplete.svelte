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
		<p class="end">That's the last level on this path. Pick another one from the level list.</p>
	{/if}

	<div class="actions">
		<button type="button" class="button" onclick={retry}>Retry</button>
		{#if nextLevelSlug}
			<a class="button" href={resolve('/app')}>All levels</a>
			<a
				class="button primary"
				href={resolve('/app/levels/[slug]', { slug: nextLevelSlug })}
				bind:this={primary}
				onclick={() => (open = false)}
			>
				Next level <span aria-hidden="true">→</span>
			</a>
		{:else}
			<a class="button primary" href={resolve('/app')} bind:this={primary}>All levels</a>
		{/if}
	</div>
</dialog>

<style>
	/* buttons use the design system's .button and .button.primary */
	.level-complete {
		box-sizing: border-box;
		width: min(30rem, calc(100vw - 2rem));
		padding: var(--space-6);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-pixel);
		color: var(--color-text);
		text-align: center;
	}

	.level-complete::backdrop {
		background: rgb(0 0 0 / 0.5);
	}

	h2 {
		margin: 0 0 var(--space-2);
		font-family: var(--font-display);
		font-size: var(--text-3xl);
		font-weight: 400;
		line-height: 1;
	}

	.subtitle,
	.end {
		margin: 0 0 var(--space-5);
		color: var(--color-text-muted);
		line-height: 1.5;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: var(--space-3);
	}
</style>
