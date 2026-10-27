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
		gap: 0.75rem;
		font-size: 0.875rem;
		color: #333;
	}

	.headline {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		margin: 0;
		font-weight: 600;
	}

	.dot {
		flex: none;
		width: 0.625rem;
		height: 0.625rem;
		border-radius: 50%;
		background: #8a8a8a;
	}

	.headline.success {
		color: #1a7f37;
	}
	.headline.success .dot {
		background: #1a7f37;
	}
	.headline.warning {
		color: #9a6700;
	}
	.headline.warning .dot {
		background: #bf8700;
	}
	.headline.error,
	.headline.offline {
		color: #b42318;
	}
	.headline.error .dot,
	.headline.offline .dot {
		background: #d92d20;
	}

	.items {
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.item {
		border: 1px solid #d0d0d0;
		border-radius: 6px;
		overflow: hidden;
	}

	.location {
		display: flex;
		align-items: center;
		gap: 0.5rem;
		width: 100%;
		padding: 0.375rem 0.625rem;
		border: none;
		border-bottom: 1px solid #e5e5e5;
		background: #f7f7f7;
		color: #333;
		font: inherit;
		font-weight: 600;
		text-align: left;
		cursor: pointer;
	}

	.location:disabled {
		cursor: default;
	}

	.location:not(:disabled):hover {
		background: #eef2f8;
	}

	.location:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: -2px;
	}

	.badge {
		padding: 0 0.375rem;
		border-radius: 4px;
		font-size: 0.75rem;
		color: #fff;
		background: #6b6b6b;
	}

	.item.error .badge {
		background: #d92d20;
	}

	.item.warning .badge {
		background: #9a6700;
	}

	.message {
		margin: 0;
		padding: 0.5rem 0.625rem;
		overflow-x: auto;
		font:
			12.5px / 1.6 ui-monospace,
			SFMono-Regular,
			Consolas,
			monospace;
		white-space: pre-wrap;
	}
</style>
