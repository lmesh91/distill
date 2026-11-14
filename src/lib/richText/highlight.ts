import type { HighlighterCore } from 'shiki/core';

const theme = 'github-light';
// only Lean is loaded; other fenced languages render as plain code
const leanAliases = new Set(['lean4', 'lean']);

let highlighter: Promise<HighlighterCore> | undefined;

function getHighlighter() {
	highlighter ??= Promise.all([import('shiki/core'), import('shiki/engine/javascript')]).then(
		([{ createHighlighterCore }, { createJavaScriptRegexEngine }]) =>
			createHighlighterCore({
				themes: [import('@shikijs/themes/github-light')],
				langs: [import('@shikijs/langs/lean4')],
				engine: createJavaScriptRegexEngine()
			})
	);
	return highlighter;
}

export function canHighlight(lang: string) {
	return leanAliases.has(lang);
}

/** HTML for highlighted code, or undefined for a language we don't load */
export async function highlightCode(code: string, lang: string, block: boolean) {
	if (!canHighlight(lang)) return undefined;
	const shiki = await getHighlighter();
	return shiki.codeToHtml(code, {
		lang: 'lean4',
		theme,
		structure: block ? 'classic' : 'inline'
	});
}
