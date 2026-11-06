<script lang="ts">
	import { describeProofCheck, type ProofCheckState } from '$lib/levels/proofCheck';

	// shows where a "Check proof" request is (#57): waiting for Lean, checking, or the verdict
	let { check }: { check: ProofCheckState } = $props();

	// tick once a second while waiting or checking so the elapsed time counts up
	let now = $state(Date.now());
	const busy = $derived(check.kind === 'waiting' || check.kind === 'running');
	$effect(() => {
		if (!busy) return;
		now = Date.now();
		const interval = setInterval(() => (now = Date.now()), 1000);
		return () => clearInterval(interval);
	});

	const view = $derived(describeProofCheck(check, Math.max(now, Date.now())));
</script>

<!-- the live region only gets the title, so screen readers hear each stage once, not every tick -->
<div class="proof-check {view?.tone ?? ''} {check.kind}" hidden={!view}>
	{#if view}
		<svg class="icon" viewBox="0 0 20 20" width="20" height="20" aria-hidden="true">
			{#if check.kind === 'running'}
				<circle class="track" cx="10" cy="10" r="7.5" />
				<path class="arc" d="M10 2.5a7.5 7.5 0 0 1 7.5 7.5" />
			{:else if check.kind === 'waiting'}
				<!-- three dots that light up in turn: queued, not yet running -->
				<circle class="dot" cx="4" cy="10" r="2" />
				<circle class="dot" cx="10" cy="10" r="2" />
				<circle class="dot" cx="16" cy="10" r="2" />
			{:else if check.kind === 'accepted'}
				<circle class="disc" cx="10" cy="10" r="9" />
				<path class="mark" d="M5.5 10.5 8.5 13.5 14.5 6.5" />
			{:else if check.kind === 'rejected'}
				<circle class="disc" cx="10" cy="10" r="9" />
				<path class="mark" d="M6.5 6.5l7 7m0-7-7 7" />
			{:else}
				<circle class="disc" cx="10" cy="10" r="9" />
				<path class="mark" d="M10 5v6" />
				<circle class="mark-dot" cx="10" cy="14.5" r="1.25" />
			{/if}
		</svg>
		<div class="text">
			<p class="title">
				<span role="status" aria-live="polite">{view.title}</span>
				{#if view.elapsed !== undefined}
					<span class="elapsed" aria-hidden="true">{view.elapsed}s</span>
				{/if}
			</p>
			<p class="detail">{view.detail}</p>
		</div>
	{/if}
</div>

<style>
	/* colors use the design system (#20) tokens; the fallbacks keep it readable without them */
	.proof-check {
		display: flex;
		align-items: flex-start;
		gap: 0.625rem;
		min-width: 0;
		padding: 0.5rem 0.75rem;
		border: 2px solid var(--color-border, #1b1b1f);
		border-radius: var(--radius, 6px);
		background: var(--color-surface, #fff);
		color: var(--color-text, #1b1b1f);
		font-size: var(--text-sm, 0.875rem);
	}

	.proof-check[hidden] {
		display: none;
	}

	.proof-check.success {
		border-color: var(--color-success, #1a7f37);
		background: var(--color-success-soft, #e6f4ea);
	}

	.proof-check.error {
		border-color: var(--color-error, #b42318);
		background: var(--color-error-soft, #fdeceb);
	}

	.icon {
		flex: none;
		margin-top: 0.05rem;
		fill: none;
		stroke: currentColor;
		stroke-width: 2.25;
		stroke-linecap: round;
		stroke-linejoin: round;
	}

	.busy .icon {
		color: var(--color-brand, #1a6db8);
	}

	.success .icon {
		color: var(--color-success, #1a7f37);
	}

	.error .icon {
		color: var(--color-error, #b42318);
	}

	.disc,
	.dot,
	.mark-dot {
		stroke: none;
		fill: currentColor;
	}

	.mark {
		stroke: #fff;
	}

	.mark-dot {
		fill: #fff;
	}

	.track {
		opacity: 0.25;
	}

	.running .icon {
		animation: spin 0.8s linear infinite;
	}

	.dot {
		animation: blink 1.2s ease-in-out infinite;
		opacity: 0.25;
	}

	.dot:nth-child(2) {
		animation-delay: 0.2s;
	}

	.dot:nth-child(3) {
		animation-delay: 0.4s;
	}

	.text {
		min-width: 0;
	}

	p {
		margin: 0;
	}

	.title {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		gap: 0.5rem;
		font-weight: var(--weight-bold, 650);
	}

	.success .title {
		color: var(--color-success, #1a7f37);
	}

	.error .title {
		color: var(--color-error, #b42318);
	}

	.elapsed {
		color: var(--color-text-subtle, #6e6e78);
		font-weight: var(--weight-regular, 400);
		font-variant-numeric: tabular-nums;
	}

	.detail {
		color: var(--color-text-muted, #5b5b66);
	}

	@keyframes spin {
		to {
			transform: rotate(360deg);
		}
	}

	@keyframes blink {
		40% {
			opacity: 1;
		}
	}

	/* no spinning for people who turn off animations; a slow pulse still shows it's busy */
	@media (prefers-reduced-motion: reduce) {
		.running .icon,
		.dot {
			animation: pulse 1.6s ease-in-out infinite;
		}

		@keyframes pulse {
			50% {
				opacity: 0.4;
			}
		}
	}
</style>
