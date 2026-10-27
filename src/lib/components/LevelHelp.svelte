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
		border: 1px solid #4a4a4a;
		border-radius: 50%;
		background: #fff;
		color: #333;
		font: inherit;
		font-weight: 600;
		cursor: help;
	}

	button:hover {
		background: #f3f3f3;
	}

	button:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: 2px;
	}

	.tooltip {
		position: absolute;
		z-index: 50;
		top: 100%;
		right: 0;
		width: min(22rem, calc(100vw - 2rem));
		padding-top: 0.5rem;
	}

	.content {
		max-height: 65dvh;
		overflow-y: auto;
		padding: 1rem;
		border: 1px solid #d0d0d0;
		border-radius: 8px;
		background: #fff;
		color: #333;
		box-shadow: 0 4px 16px #0002;
		font-size: 0.875rem;
		line-height: 1.5;
	}

	.content :global(h2) {
		margin: 0 0 0.5rem;
		font-size: 0.875rem;
	}

	.content :global(p) {
		margin: 0;
	}

	.content :global(p + h2) {
		margin-top: 1rem;
	}
</style>
