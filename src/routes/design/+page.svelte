<script lang="ts">
	import SaveStatus from '$lib/components/SaveStatus.svelte';
	import type { SaveState } from '$lib/levels/autosave';

	// a live preview of the design system (#20); the source of truth is src/lib/styles/tokens.css
	const colorGroups = [
		{
			title: 'Brand and accents',
			colors: [
				['--color-brand', 'Links, primary buttons, focus'],
				['--color-brand-strong', 'Brand hover'],
				['--color-brand-soft', 'Tinted backgrounds'],
				['--color-highlight', 'Marker highlight, current page'],
				['--color-pink', 'Accent'],
				['--color-mint', 'Accent']
			]
		},
		{
			title: 'Surfaces and text',
			colors: [
				['--color-ink', 'Text, borders, shadows'],
				['--color-text-muted', 'Secondary text'],
				['--color-text-subtle', 'Timestamps, placeholders'],
				['--color-page', 'Page background'],
				['--color-surface', 'Panels, cards, editor'],
				['--color-surface-sunken', 'Title bars, gutters'],
				['--color-border-subtle', 'Dividers inside panels']
			]
		},
		{
			title: 'Status',
			colors: [
				['--color-success', 'Accepted, saved'],
				['--color-warning', 'Warnings'],
				['--color-error', 'Errors'],
				['--color-neutral', 'Info, idle']
			]
		}
	];

	const typeScale = [
		['--text-3xl', 'Page title', true],
		['--text-2xl', 'Section heading', true],
		['--text-xl', 'Small heading', true],
		['--text-lg', 'Lead paragraph', false],
		['--text-md', 'Body text', false],
		['--text-sm', 'Panel text and labels', false],
		['--text-xs', 'Timestamps and badges', false]
	] as const;

	const spacing = ['1', '2', '3', '4', '5', '6', '7', '8'];

	const now = Date.now();
	const saveStates: SaveState[] = [
		{ kind: 'idle' },
		{ kind: 'saving' },
		{ kind: 'saved', at: now },
		{ kind: 'error', message: 'Could not reach the server.', retrying: true }
	];
</script>

<svelte:head>
	<title>Design system · Distill</title>
	<meta name="robots" content="noindex" />
</svelte:head>

<main class="design">
	<header>
		<h1 class="display">Design system</h1>
		<p class="muted">
			Colors, type, spacing and components for Distill. Use the variables in
			<code>src/lib/styles/tokens.css</code> and the classes in
			<code>src/lib/styles/components.css</code> instead of raw values. The guide is in
			<code>docs/design-system/README.md</code>.
		</p>
	</header>

	<section aria-labelledby="colors">
		<h2 id="colors" class="display">Colors</h2>
		{#each colorGroups as group (group.title)}
			<h3>{group.title}</h3>
			<ul class="swatches">
				{#each group.colors as [name, use] (name)}
					<li>
						<span class="swatch" style:background={`var(${name})`}></span>
						<code>{name}</code>
						<span class="muted">{use}</span>
					</li>
				{/each}
			</ul>
		{/each}
	</section>

	<section aria-labelledby="type">
		<h2 id="type" class="display">Typography</h2>
		<p class="muted">
			<strong>Jersey 10</strong> (pixel) for headings 24px and up, <strong>Space Grotesk</strong>
			for everything else, and the system monospace font for Lean code.
		</p>
		<ul class="type-scale">
			{#each typeScale as [name, use, display] (name)}
				<li>
					<span class:display style:font-size={`var(${name})`}>{use}</span>
					<code>{name}</code>
				</li>
			{/each}
		</ul>
		<pre class="code-sample"><code
				>theorem and_swap (p q : Prop) : p ∧ q → q ∧ p := by
  intro ⟨hp, hq⟩
  exact ⟨hq, hp⟩</code
			></pre>
		<p>
			Use <span class="highlight">the marker highlight</span> sparingly, for the one phrase that matters
			most.
		</p>
	</section>

	<section aria-labelledby="spacing">
		<h2 id="spacing" class="display">Spacing</h2>
		<ul class="spacing">
			{#each spacing as step (step)}
				<li>
					<span class="bar" style:width={`var(--space-${step})`}></span>
					<code>--space-{step}</code>
				</li>
			{/each}
		</ul>
	</section>

	<section aria-labelledby="components">
		<h2 id="components" class="display">Components</h2>

		<h3>Buttons</h3>
		<div class="row">
			<button class="button primary" type="button">Check proof</button>
			<button class="button" type="button">Reset code</button>
			<button class="button ghost" type="button">Cancel</button>
			<button class="button small" type="button">Hints</button>
			<button class="button primary" type="button" disabled>Disabled</button>
		</div>

		<h3>Badges</h3>
		<div class="row">
			<span class="badge">Info</span>
			<span class="badge success">Accepted</span>
			<span class="badge warning">Warning</span>
			<span class="badge error">Error</span>
		</div>

		<h3>Card</h3>
		<div class="card sample-card">
			<h4>Prove from scratch</h4>
			<p class="muted">Cards are for standalone content like level and mode tiles.</p>
		</div>

		<h3>Save status</h3>
		<div class="row save-states">
			{#each saveStates as saveState (saveState.kind)}
				<span class="save-sample"><SaveStatus {saveState} /></span>
			{/each}
		</div>
	</section>
</main>

<style>
	.design {
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-7) var(--page-gutter) var(--space-8);
	}

	h1 {
		margin: 0 0 var(--space-2);
		font-size: var(--text-3xl);
	}

	header p {
		max-width: 46rem;
	}

	section {
		margin-top: var(--space-7);
	}

	h2 {
		margin: 0 0 var(--space-4);
		font-size: var(--text-2xl);
	}

	h3 {
		margin: var(--space-5) 0 var(--space-3);
		font-size: var(--text-sm);
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: var(--color-text-muted);
	}

	h4 {
		margin: 0 0 var(--space-2);
	}

	ul {
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.swatches {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(14rem, 1fr));
		gap: var(--space-3);
	}

	.swatches li {
		display: grid;
		grid-template-columns: 2.5rem minmax(0, 1fr);
		column-gap: var(--space-3);
		align-items: center;
		font-size: var(--text-sm);
	}

	.swatch {
		grid-row: span 2;
		width: 2.5rem;
		height: 2.5rem;
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
	}

	.type-scale li {
		display: flex;
		flex-wrap: wrap;
		align-items: baseline;
		justify-content: space-between;
		gap: var(--space-4);
		padding: var(--space-2) 0;
		border-bottom: 1px solid var(--color-border-subtle);
	}

	.code-sample {
		margin: var(--space-5) 0;
		padding: var(--space-4);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
		line-height: var(--leading-code);
		overflow-x: auto;
	}

	.spacing li {
		display: flex;
		align-items: center;
		gap: var(--space-4);
		padding: var(--space-1) 0;
	}

	.bar {
		height: 1rem;
		background: var(--color-brand);
	}

	.row {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-3);
	}

	.sample-card {
		max-width: 22rem;
	}

	.sample-card p {
		margin: 0;
	}

	.save-sample {
		display: inline-flex;
		padding: var(--space-2) var(--space-3);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface-sunken);
	}
</style>
