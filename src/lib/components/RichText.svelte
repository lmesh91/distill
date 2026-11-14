<script lang="ts">
	import katex from 'katex';
	import 'katex/dist/katex.min.css';
	import RichCode from '$lib/components/RichCode.svelte';
	import { parseRichText } from '$lib/richText/parse';

	/** level text with `$…$` / `$$…$$` LaTeX and Markdown-style code; see `parseRichText` */
	let { text }: { text: string } = $props();

	const segments = $derived(parseRichText(text));

	function renderMath(tex: string, displayMode: boolean) {
		return katex.renderToString(tex, { displayMode, throwOnError: false });
	}
</script>

<!-- eslint-disable svelte/no-at-html-tags -- KaTeX escapes its input -->
<!-- prettier-ignore -->
{#each segments as segment, index (index)}{#if segment.kind === 'text'}{segment.text}{:else if segment.kind === 'math'}{@html renderMath(segment.tex, segment.display)}{:else}<RichCode code={segment.code} lang={segment.lang} block={segment.block} />{/if}{/each}
