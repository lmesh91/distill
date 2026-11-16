<script lang="ts">
	import katex from 'katex';
	import 'katex/dist/katex.min.css';
	import RichCode from '$lib/components/RichCode.svelte';
	import type { TextPart } from '$lib/lean/client';
	import { parseRichText, segmentsFromParts } from '$lib/richText/parse';

	/**
	 * Either level text with `$…$` / `$$…$$` LaTeX and Markdown-style code (see
	 * `parseRichText`), or the parts of a Lean translation.
	 */
	let props: { text: string } | { parts: TextPart[] } = $props();

	const segments = $derived(
		'parts' in props ? segmentsFromParts(props.parts) : parseRichText(props.text)
	);

	function renderMath(tex: string, displayMode: boolean) {
		return katex.renderToString(tex, { displayMode, throwOnError: false });
	}
</script>

<!-- eslint-disable svelte/no-at-html-tags -- KaTeX escapes its input -->
<!-- prettier-ignore -->
{#each segments as segment, index (index)}{#if segment.kind === 'text'}{segment.text}{:else if segment.kind === 'math'}{@html renderMath(segment.tex, segment.display)}{:else}<RichCode code={segment.code} lang={segment.lang} block={segment.block} />{/if}{/each}
