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

	const modes = [
		{
			title: 'Guided translation',
			body: 'Start from a proof written in English and rewrite it in Lean, one step at a time.'
		},
		{
			title: 'Prove from scratch',
			body: 'Get a theorem with no proof attached and write your own, using the tactics you have unlocked.'
		},
		{
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
			<h1 id="hero-title">Learn Lean by translating proofs you already know.</h1>
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
		<h2 id="how-title">How Distill works</h2>
		<ul class="modes">
			{#each modes as mode (mode.title)}
				<li class="mode">
					<h3>{mode.title}</h3>
					<p>{mode.body}</p>
				</li>
			{/each}
		</ul>
	</section>
</main>

<style>
	.home {
		box-sizing: border-box;
		max-width: 75rem;
		margin: 0 auto;
		padding: 3rem 1rem 4rem;
		color: #333;
	}

	.hero {
		display: grid;
		grid-template-columns: minmax(0, 1fr) minmax(0, 1.4fr);
		align-items: center;
		gap: 3rem;
	}

	h1 {
		margin: 0 0 1rem;
		font-size: clamp(2rem, 4vw, 2.75rem);
		line-height: 1.15;
	}

	.lead {
		margin: 0 0 1.75rem;
		font-size: 1.125rem;
		line-height: 1.6;
		color: #555;
	}

	.ctas {
		display: flex;
		flex-wrap: wrap;
		gap: 0.75rem;
	}

	.button {
		display: inline-block;
		padding: 0.75rem 1.25rem;
		border: 2px solid #333;
		border-radius: 6px;
		color: #333;
		font-weight: 600;
		text-decoration: none;
	}

	.button.primary {
		background: #333;
		color: #fff;
	}

	.button:hover {
		background: #f3f3f3;
	}

	.button.primary:hover {
		background: #4a4a4a;
	}

	.button:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: 2px;
	}

	.example {
		display: grid;
		grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
		align-items: stretch;
		gap: 0.75rem;
		margin: 0;
	}

	.pane {
		padding: 0.75rem 1rem;
		border: 2px solid #4a4a4a;
		border-radius: 6px;
		background: #fff;
	}

	.pane:first-child {
		background: #f3f3f3;
	}

	.pane-title {
		margin: 0 0 0.5rem;
		font-size: 0.875rem;
		font-weight: 600;
	}

	pre {
		margin: 0;
		overflow-x: auto;
		font:
			13px / 1.8 ui-monospace,
			SFMono-Regular,
			Consolas,
			monospace;
	}

	ol {
		margin: 0;
		padding-left: 1.25rem;
		font-size: 0.9375rem;
		line-height: 1.5;
	}

	ol li + li {
		margin-top: 0.375rem;
	}

	.arrow {
		align-self: center;
		font-size: 1.5rem;
	}

	figcaption {
		grid-column: 1 / -1;
		font-size: 0.875rem;
		color: #555;
	}

	.how {
		margin-top: 4rem;
	}

	h2 {
		margin: 0 0 1.25rem;
		font-size: 1.5rem;
	}

	.modes {
		display: grid;
		grid-template-columns: repeat(3, minmax(0, 1fr));
		gap: 1rem;
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.mode {
		padding: 1.25rem;
		border: 2px solid #4a4a4a;
		border-radius: 6px;
	}

	h3 {
		margin: 0 0 0.5rem;
		font-size: 1.125rem;
	}

	.mode p {
		margin: 0;
		line-height: 1.5;
		color: #555;
	}

	@media (max-width: 60rem) {
		.hero,
		.modes {
			grid-template-columns: minmax(0, 1fr);
		}

		.hero {
			gap: 2rem;
		}
	}

	@media (max-width: 36rem) {
		.home {
			padding-top: 2rem;
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
