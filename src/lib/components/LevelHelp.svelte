<script lang="ts">
	import type { Snippet } from 'svelte';

	let {
		label = 'About this level',
		children
	}: {
		label?: string;
		children: Snippet;
	} = $props();

	const id = $props.id();
	let container: HTMLDivElement;
	let hovered = $state(false);
	let focused = $state(false);
	let pinned = $state(false);
	const open = $derived(hovered || focused || pinned);

	function dismiss() {
		hovered = focused = pinned = false;
	}
</script>

<svelte:window
	onkeydown={(event) => {
		if (event.key === 'Escape') dismiss();
	}}
	onpointerdown={(event) => {
		if (!container.contains(event.target as Node)) dismiss();
	}}
/>

<div
	class="help"
	role="group"
	bind:this={container}
	onpointerenter={(event) => {
		if (event.pointerType === 'mouse') hovered = true;
	}}
	onpointerleave={() => (hovered = false)}
	onfocusin={() => (focused = true)}
	onfocusout={(event) => {
		if (!container.contains(event.relatedTarget as Node)) focused = false;
	}}
>
	<button
		type="button"
		aria-label={label}
		aria-describedby={id}
		aria-expanded={open}
		aria-controls={id}
		onclick={() => {
			if (pinned) dismiss();
			else pinned = true;
		}}
	>
		?
	</button>
	<div class="tooltip" {id} role="tooltip" hidden={!open}>
		<div class="content">{@render children()}</div>
	</div>
</div>

<style>
	.help {
		position: relative;
		display: inline-flex;
	}

	button {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 1.75rem;
		height: 1.75rem;
		padding: 0;
		border: var(--border-width) solid var(--color-border);
		border-radius: 50%;
		background: var(--color-surface);
		box-shadow: var(--shadow-pixel-sm);
		color: var(--color-ink);
		font: inherit;
		font-weight: var(--weight-bold);
		cursor: help;
	}

	button:hover {
		background: var(--color-highlight);
	}

	.tooltip {
		position: absolute;
		z-index: 50;
		top: 100%;
		right: 0;
		width: min(22rem, calc(100vw - 2rem));
		padding-top: var(--space-2);
	}

	.content {
		max-height: 65dvh;
		overflow-y: auto;
		padding: var(--space-4);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		color: var(--color-text);
		box-shadow: var(--shadow-pixel);
		font-size: var(--text-sm);
		line-height: var(--leading-normal);
	}

	.content :global(h2) {
		margin: 0 0 var(--space-2);
		font-size: var(--text-sm);
	}

	.content :global(p) {
		margin: 0;
	}

	.content :global(p + h2) {
		margin-top: var(--space-4);
	}
</style>
