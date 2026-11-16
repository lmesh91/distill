<script lang="ts">
	import LeanEditor from '$lib/components/LeanEditor.svelte';
	import LeanResults from '$lib/components/LeanResults.svelte';
	import type { Diagnostic } from '$lib/lean/client';

	let code = $state('import Distill\n\nexample : 1 + 1 = 2 := by\n  rfl\n');
	let status = $state('Connecting…');
	let diagnostics = $state<Diagnostic[]>([]);
	let leanEditor = $state<LeanEditor>();
</script>

<svelte:head><title>Lean · Distill</title></svelte:head>

<main class="sandbox">
	<header>
		<h1 class="display">Lean sandbox</h1>
		<p class="muted">Try out Lean freely. Nothing here is saved or scored.</p>
	</header>

	<div class="workspace">
		<LeanEditor
			bind:this={leanEditor}
			bind:value={code}
			onstatus={(nextStatus) => (status = nextStatus)}
			ondiagnostics={(nextDiagnostics) => (diagnostics = nextDiagnostics)}
		/>

		<section class="output" aria-labelledby="sandbox-output">
			<h2 id="sandbox-output">Lean output</h2>
			<LeanResults
				{status}
				{diagnostics}
				onselect={(line, character) => leanEditor?.goTo(line, character)}
			/>
		</section>
	</div>
</main>

<style>
	.sandbox {
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-6) var(--page-gutter) var(--space-7);
	}

	h1 {
		margin: 0 0 var(--space-1);
		font-size: var(--text-2xl);
	}

	header p {
		margin: 0 0 var(--space-5);
	}

	.workspace {
		display: grid;
		grid-template-columns: minmax(0, 1.6fr) minmax(16rem, 1fr);
		align-items: start;
		gap: var(--space-4);
	}

	.output {
		padding: var(--space-3) var(--space-4);
		border: var(--border-width) solid var(--color-border);
		border-radius: var(--radius);
		background: var(--color-surface);
	}

	h2 {
		margin: 0 0 var(--space-2);
		font-size: var(--text-xs);
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: var(--color-text-muted);
	}

	@media (max-width: 48rem) {
		.workspace {
			grid-template-columns: minmax(0, 1fr);
		}
	}
</style>
