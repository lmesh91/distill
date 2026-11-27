<script lang="ts">
	import { highlightCode } from '$lib/richText/highlight';

	let { code, lang, block }: { code: string; lang: string; block: boolean } = $props();

	// plain code until the highlighter loads in the browser
	let html = $state<string>();

	$effect(() => {
		let current = true;
		html = undefined;
		highlightCode(code, lang, block).then(
			(result) => {
				if (current) html = result;
			},
			() => {}
		);
		return () => {
			current = false;
		};
	});
</script>

<!-- eslint-disable svelte/no-at-html-tags -- shiki escapes the code -->
<!-- prettier-ignore -->
{#if block}{#if html}<div class="code-block">{@html html}</div>{:else}<div class="code-block"><pre><code>{code}</code></pre></div>{/if}{:else if html}<code class="inline-code">{@html html}</code>{:else}<code class="inline-code">{code}</code>{/if}

<style>
	.code-block :global(pre) {
		margin: 0.5rem 0;
		padding: 0.5rem 0.75rem;
		overflow-x: auto;
		border-radius: 4px;
		background: var(--color-surface-sunken);
		color: var(--color-text);
		font-size: 1em;
		white-space: pre;
	}

	.inline-code {
		padding: 0.1em 0.3em;
		border-radius: 3px;
		background: var(--color-surface-sunken);
		color: var(--color-text);
		font-size: 1em;
	}

	/* Both palettes are in the markup, so theme changes need no JS or re-highlighting. */
	.code-block :global(span),
	.inline-code :global(span) {
		color: var(--shiki-light);
	}

	:global(:root[data-theme='dark']) .code-block :global(span),
	:global(:root[data-theme='dark']) .inline-code :global(span) {
		color: var(--shiki-dark);
	}

	@media (prefers-color-scheme: dark) {
		:global(:root:not([data-theme='light'])) .code-block :global(span),
		:global(:root:not([data-theme='light'])) .inline-code :global(span) {
			color: var(--shiki-dark);
		}
	}
</style>
