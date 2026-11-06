<script lang="ts">
	import { resolve } from '$app/paths';

	// A short proof using only tactics Distill supports, with the English a learner would see.
	const leanExample = [
		'theorem and_swap (p q : Prop) :',
		'    p ∧ q → q ∧ p := by',
		'  intro h',
		'  cases h with',
		'  | intro hp hq =>',
		'    constructor',
		'    · assumption',
		'    · assumption'
	];

	const englishExample = [
		'Let p and q be propositions. We show that if p and q both hold, then q and p both hold.',
		'Suppose p ∧ q, and call this assumption h.',
		'Split h into its two parts: hp, a proof of p, and hq, a proof of q.',
		'To prove q ∧ p, we prove q and p separately.',
		'q holds by hq, and p holds by hp. ∎'
	];

	// accent is the color strip on top of each card, from the design system's accents
	const modes = [
		{
			accent: 'mint',
			title: 'Guided translation',
			body: 'Start from a proof written in English and rewrite it in Lean, one step at a time.'
		},
		{
			accent: 'pink',
			title: 'Prove from scratch',
			body: 'Get a theorem with no proof attached and write your own, using the tactics you have unlocked.'
		},
		{
			accent: 'highlight',
			title: 'Live English',
			body: 'As you type, Distill turns your Lean into plain English so you can check that it says what you mean.'
		}
	];
</script>

<svelte:head>
	<title>Distill · Learn Lean by translating proofs</title>
	<meta
		name="description"
		content="Distill teaches you to write proofs in the Lean theorem prover by translating proofs you already know, with live English translations of your code."
	/>
</svelte:head>

<main class="home">
	<section class="hero" aria-labelledby="hero-title">
		<div class="pitch">
			<h1 id="hero-title" class="display">
				Learn Lean by translating <span class="highlight">proofs you already know.</span>
			</h1>
			<p class="lead">
				Distill is a game for people who already write math proofs. Each level asks you to prove
				something in the Lean theorem prover, and every line you write is translated back into
				English so you can see exactly what Lean thinks you said.
			</p>
			<div class="ctas">
				<a class="button primary" href={resolve('/app')}>Start learning</a>
				<a class="button" href={resolve('/app/lean')}>Try the sandbox</a>
			</div>
		</div>

		<figure class="example">
			<div class="pane">
				<p class="pane-title">Lean</p>
				<pre><code>{leanExample.join('\n')}</code></pre>
			</div>
			<span class="arrow" aria-hidden="true">→</span>
			<div class="pane">
				<p class="pane-title">English</p>
				<ol>
					{#each englishExample as line, index (index)}
						<li>{line}</li>
					{/each}
				</ol>
			</div>
			<figcaption>A Lean proof and the English translation Distill shows next to it.</figcaption>
		</figure>
	</section>

	<section class="how" aria-labelledby="how-title">
		<h2 id="how-title" class="display">How Distill works</h2>
		<ul class="modes">
			{#each modes as mode (mode.title)}
				<li class="mode card" style:--accent={`var(--color-${mode.accent})`}>
					<h3>{mode.title}</h3>
					<p>{mode.body}</p>
				</li>
			{/each}
		</ul>
	</section>
</main>

<style>
	.home {
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-7) var(--page-gutter) var(--space-8);
	}

	.hero {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(0, 1.4fr);
		align-items: center;
		gap: var(--space-7);
	}

	h1 {
		margin: 0 0 var(--space-4);
		font-size: var(--text-3xl);
	}

	.lead {
		margin: 0 0 var(--space-5);
		font-size: var(--text-lg);
		line-height: 1.6;
		color: var(--color-text-muted);
	}

	.ctas {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-3);
	}

	.ctas .button {
		min-height: 3rem;
		padding-inline: var(--space-5);
	}

	.example {
		display: grid;
		grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
		align-items: stretch;
		gap: var(--space-3);
		margin: 0;
	}

	.pane {
		padding: var(--space-3) var(--space-4);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius-lg);
		background: var(--color-surface);
		box-shadow: var(--shadow-pixel);
	}

	.pane:first-child {
		background: var(--color-surface-sunken);
	}

	.pane-title {
		margin: 0 0 var(--space-2);
		font-size: var(--text-xs);
		font-weight: var(--weight-bold);
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: var(--color-text-muted);
	}

	pre {
		margin: 0;
		overflow-x: auto;
		font-size: 13px;
		line-height: var(--leading-code);
	}

	ol {
		margin: 0;
		padding-left: 1.25rem;
		font-size: 0.9375rem;
		line-height: var(--leading-normal);
	}

	ol li + li {
		margin-top: var(--space-2);
	}

	.arrow {
		align-self: center;
		font-size: var(--text-xl);
		color: var(--color-brand);
	}

	figcaption {
		grid-column: 1 / -1;
		margin-top: var(--space-2);
		font-size: var(--text-sm);
		color: var(--color-text-muted);
	}

	.how {
		margin-top: var(--space-8);
	}

	h2 {
		margin: 0 0 var(--space-5);
		font-size: var(--text-2xl);
	}

	.modes {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: var(--space-5);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	/* a colored strip on top of each mode card */
	.mode {
		border-top-width: 10px;
		border-top-color: var(--accent);
		box-shadow:
			0 -2px 0 var(--color-ink),
			var(--shadow-pixel);
	}

	h3 {
		margin: 0 0 var(--space-2);
		font-size: var(--text-lg);
	}

	.mode p {
		margin: 0;
		color: var(--color-text-muted);
	}

	@media (max-width: 60rem) {
		.hero,
		.modes {
			grid-template-columns: minmax(0, 1fr);
		}

		.hero {
			gap: var(--space-6);
		}
	}

	@media (max-width: 36rem) {
		.home {
			padding-top: var(--space-6);
		}

		.example {
			grid-template-columns: minmax(0, 1fr);
		}

		.arrow {
			justify-self: center;
			transform: rotate(90deg);
		}
	}
</style>
