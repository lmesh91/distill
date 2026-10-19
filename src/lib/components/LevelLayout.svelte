<script lang="ts">
	import { onMount, type Snippet } from 'svelte';
	import { resolve } from '$app/paths';
	import ResizeHandle from '$lib/components/ResizeHandle.svelte';
	import type { LevelType } from '$lib/types/level';

	let {
		title,
		mode,
		toolbar,
		goal,
		brief,
		editor,
		actions,
		output,
		translation
	}: {
		title: string;
		mode: LevelType;
		toolbar?: Snippet;
		goal: Snippet;
		brief?: Snippet;
		editor: Snippet;
		actions?: Snippet;
		output: Snippet;
		translation?: Snippet;
	} = $props();

	const id = $props.id();
	const minSideRem = 10;
	const minWorkspaceRem = 16;

	let editorPane: HTMLDivElement;
	let outputPane: HTMLElement;

	let columnsWidth = $state(0);
	let workspaceHeight = $state(0);
	let leftSize = $state(0);
	let workspaceSize = $state(0);
	let rightSize = $state(0);
	let editorSize = $state(0);
	let outputSize = $state(0);

	// undefined until the user resizes, so the default proportions apply
	let leftWidth = $state<number>();
	let rightWidth = $state<number>();
	let editorHeight = $state<number>();

	let editorMin = $state(0);
	let outputMin = $state(0);
	let start = { left: 0, right: 0, workspace: 0, editor: 0, output: 0 };

	const columns = $derived(
		[
			`minmax(${minSideRem}rem, ${leftWidth ? `${leftWidth}px` : '1fr'})`,
			'auto',
			`minmax(${minWorkspaceRem}rem, 1.5fr)`,
			'auto',
			`minmax(${minSideRem}rem, ${rightWidth ? `${rightWidth}px` : '1.2fr'})`
		].join(' ')
	);
	const rows = $derived(
		[
			`minmax(${editorMin}px, ${editorHeight ? `${editorHeight}px` : '3fr'})`,
			'auto',
			'auto',
			`minmax(${outputMin}px, 1fr)`
		].join(' ')
	);

	onMount(() => {
		editorMin = titleBarHeight(editorPane);
		outputMin = titleBarHeight(outputPane);
	});

	/** height of a pane from its top edge to the bottom of its heading's container chrome */
	function titleBarHeight(pane: HTMLElement) {
		const heading = pane.querySelector('h2');
		if (!heading?.parentElement) return 0;
		const container = getComputedStyle(heading.parentElement);
		return (
			heading.getBoundingClientRect().bottom -
			pane.getBoundingClientRect().top +
			parseFloat(container.paddingBottom) +
			parseFloat(container.borderBottomWidth)
		);
	}

	function rem(value: number) {
		return value * parseFloat(getComputedStyle(document.documentElement).fontSize);
	}

	function clamp(value: number, min: number, max: number) {
		return Math.max(min, Math.min(value, max));
	}

	function percent(part: number, whole: number) {
		return whole ? (part / whole) * 100 : 0;
	}

	function startResize() {
		start = {
			left: leftSize,
			right: rightSize,
			workspace: workspaceSize,
			editor: editorSize,
			output: outputSize
		};
	}

	function startColumnResize() {
		startResize();
		leftWidth = leftSize;
		rightWidth = rightSize;
	}

	function resizeLeft(delta: number) {
		const max = start.left + start.workspace - rem(minWorkspaceRem);
		leftWidth = clamp(start.left + delta, rem(minSideRem), max);
	}

	function resizeRight(delta: number) {
		const max = start.right + start.workspace - rem(minWorkspaceRem);
		rightWidth = clamp(start.right - delta, rem(minSideRem), max);
	}

	function resizeEditor(delta: number) {
		editorHeight = clamp(start.editor + delta, editorMin, start.editor + start.output - outputMin);
	}
</script>

<main class="level">
	<header class="top-bar">
		<div class="heading">
			<a class="back" href={resolve('/app')}><span aria-hidden="true">←</span> Map</a>
			<h1>{title}</h1>
		</div>
		<span class="mode">{mode}</span>
		{#if toolbar}
			<div class="toolbar">{@render toolbar()}</div>
		{/if}
	</header>

	<div class="columns" style:--columns={columns} bind:clientWidth={columnsWidth}>
		<div class="panel" id={`${id}-goal`} bind:offsetWidth={leftSize}>
			<h2>Your goal</h2>
			{@render goal()}
			{@render brief?.()}
		</div>

		<ResizeHandle
			orientation="vertical"
			label="Resize goal panel"
			controls={`${id}-goal`}
			value={percent(leftSize, columnsWidth)}
			onstart={startColumnResize}
			onmove={resizeLeft}
		/>

		<div
			class="workspace"
			style:--rows={rows}
			bind:offsetWidth={workspaceSize}
			bind:clientHeight={workspaceHeight}
		>
			<div class="editor" id={`${id}-editor`} bind:this={editorPane} bind:offsetHeight={editorSize}>
				{@render editor()}
			</div>
			{#if actions}
				<div class="actions">{@render actions()}</div>
			{/if}
			<ResizeHandle
				orientation="horizontal"
				label="Resize editor"
				controls={`${id}-editor`}
				value={percent(editorSize, workspaceHeight)}
				onstart={startResize}
				onmove={resizeEditor}
			/>
			<section
				class="panel split output"
				aria-labelledby={`${id}-output`}
				bind:this={outputPane}
				bind:offsetHeight={outputSize}
			>
				<h2 id={`${id}-output`}>Lean output</h2>
				<div class="panel-body">{@render output()}</div>
			</section>
		</div>

		<ResizeHandle
			orientation="vertical"
			label="Resize translation panel"
			controls={`${id}-translation-panel`}
			value={percent(rightSize, columnsWidth)}
			onstart={startColumnResize}
			onmove={resizeRight}
		/>

		<section
			class="panel split"
			id={`${id}-translation-panel`}
			aria-labelledby={`${id}-translation`}
			bind:offsetWidth={rightSize}
		>
			<h2 id={`${id}-translation`}>Live English translation</h2>
			<div class="panel-body">{@render translation?.()}</div>
		</section>
	</div>
</main>

<style>
	.level {
		display: flex;
		flex-direction: column;
		box-sizing: border-box;
		height: 100%;
		max-width: 75rem;
		margin: 0 auto;
		padding: 1rem;
	}

	.top-bar {
		display: grid;
		grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
		align-items: center;
		gap: 1.5rem;
		margin-bottom: 1rem;
		padding-bottom: 0.75rem;
		border-bottom: 1px solid #d0d0d0;
	}

	.heading {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 0.5rem 1.5rem;
	}

	.back {
		font-weight: 600;
		color: #333;
		text-decoration: none;
	}

	.back:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: 2px;
	}

	h1 {
		margin: 0;
		font-size: 1.25rem;
	}

	.mode {
		padding: 0.125rem 0.75rem;
		border: 1px solid #4a4a4a;
		border-radius: 999px;
		font-size: 0.75rem;
		font-weight: 600;
	}

	.toolbar {
		display: flex;
		grid-column: 3;
		justify-self: end;
		align-items: center;
		gap: 0.75rem;
	}

	.columns {
		display: grid;
		grid-template-columns: var(--columns);
		grid-template-rows: minmax(0, 1fr);
		flex: 1 1 0;
		min-height: 0;
	}

	.workspace {
		display: grid;
		grid-template-columns: minmax(0, 1fr);
		grid-template-rows: var(--rows);
		min-width: 0;
		min-height: 0;
	}

	.editor {
		display: flex;
		flex-direction: column;
		grid-row: 1;
		min-width: 0;
		min-height: 0;
		overflow: hidden;
	}

	/* the grip sits on a section's edge while the pointer is over that section */
	.panel:hover + :global(.resize-handle) :global(.grip),
	:global(.resize-handle):has(+ .workspace:hover) :global(.grip),
	.workspace:hover + :global(.resize-handle) :global(.grip),
	:global(.resize-handle):has(+ .panel:hover) :global(.grip),
	.editor:hover ~ :global(.resize-handle) :global(.grip) {
		opacity: 1;
	}

	.actions {
		display: flex;
		flex-wrap: wrap;
		grid-row: 2;
		align-items: center;
		gap: 0.75rem;
		margin-top: 0.75rem;
	}

	.workspace > :global(.resize-handle) {
		grid-row: 3;
	}

	.output {
		grid-row: 4;
	}

	.panel {
		min-width: 0;
		overflow-y: auto;
		padding: 0.75rem 1rem;
		border: 2px solid #4a4a4a;
		border-radius: 6px;
		background: #fff;
		color: #333;
	}

	.panel :global(h2) {
		margin: 0 0 0.5rem;
		font-size: 0.875rem;
	}

	.panel :global(* + h2) {
		margin-top: 1.5rem;
	}

	.split {
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.split > h2 {
		flex: none;
	}

	.panel-body {
		flex: 1;
		min-height: 0;
		overflow-y: auto;
	}

	@media (max-width: 60rem) {
		.level {
			height: auto;
		}

		.level :global(.resize-handle) {
			display: none;
		}

		.columns {
			flex: none;
			grid-template-columns: minmax(0, 1fr);
			grid-template-rows: none;
			gap: 1rem;
		}

		.workspace {
			display: flex;
			flex-direction: column;
			gap: 1rem;
		}

		.actions {
			margin-top: 0;
		}

		.panel {
			max-height: 24rem;
		}
	}
</style>
