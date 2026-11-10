<script lang="ts">
	import type { Diagnostic } from '$lib/lean/client';
	import { summarizeLeanResults } from '$lib/lean/results';

	let {
		status,
		diagnostics,
		onselect
	}: {
		status: string;
		diagnostics: Diagnostic[];
		// called with Lean's 0-based position when the user picks a problem, to jump to it
		onselect?: (line: number, character: number) => void;
	} = $props();

	const results = $derived(summarizeLeanResults(status, diagnostics));
</script>

<div class="lean-results">
	<p class="headline {results.tone}" role="status" aria-live="polite">
		<span class="dot" aria-hidden="true"></span>
		{results.headline}
	</p>

	{#if results.items.length > 0}
		<ul class="items">
			{#each results.items as item, index (index)}
				<li class="item {item.severity}">
					<button
						type="button"
						class="location"
						onclick={() => onselect?.(item.line, item.character)}
						disabled={!onselect}
						aria-label={`${item.label} at line ${item.line + 1}, column ${item.character + 1}. Go to this line.`}
					>
						<span class="badge">{item.label}</span>
						Line {item.line + 1}, col {item.character + 1}
					</button>
					<pre class="message">{item.message}</pre>
				</li>
			{/each}
		</ul>
	{/if}
</div>

<style>
	.lean-results {
		display: flex;
		flex-direction: column;
		gap: var(--space-3);
		font-family: var(--font-body);
		font-size: var(--text-sm);
		color: var(--color-text);
	}

	.headline {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin: 0;
		font-weight: var(--weight-bold);
	}

	.dot {
		flex: none;
		width: 0.625rem;
		height: 0.625rem;
		border-radius: 50%;
		background: var(--color-neutral);
	}

	.headline.success {
		color: var(--color-success);
	}
	.headline.success .dot {
		background: var(--color-success);
	}
	.headline.warning {
		color: var(--color-warning);
	}
	.headline.warning .dot {
		background: var(--color-warning);
	}
	.headline.error,
	.headline.offline {
		color: var(--color-error);
	}
	.headline.error .dot,
	.headline.offline .dot {
		background: var(--color-error);
	}

	.items {
		display: flex;
		flex-direction: column;
		gap: var(--space-2);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.item {
		border: 1px solid var(--color-border-subtle);
		border-left: 4px solid var(--color-neutral);
		border-radius: var(--radius);
		overflow: hidden;
		background: var(--color-surface);
	}

	.item.error {
		border-left-color: var(--color-error);
	}

	.item.warning {
		border-left-color: var(--color-warning);
	}

	.location {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		width: 100%;
		padding: var(--space-1) var(--space-3);
		border: none;
		border-bottom: 1px solid var(--color-border-subtle);
		background: var(--color-surface-sunken);
		color: var(--color-text);
		font: inherit;
		font-weight: var(--weight-bold);
		text-align: left;
		cursor: pointer;
	}

	.location:disabled {
		cursor: default;
	}

	.location:not(:disabled):hover {
		background: var(--color-brand-soft);
	}

	.location:focus-visible {
		outline-offset: -2px;
	}

	.badge {
		padding: 0 var(--space-2);
		border-radius: var(--radius-sm);
		font-size: var(--text-xs);
		color: var(--color-on-status);
		background: var(--color-neutral);
	}

	.item.error .badge {
		background: var(--color-error);
	}

	.item.warning .badge {
		background: var(--color-warning);
	}

	.message {
		margin: 0;
		padding: var(--space-2) var(--space-3);
		overflow-x: auto;
		font: var(--text-code-sm) / 1.6 var(--font-mono);
		white-space: pre-wrap;
	}
</style>
