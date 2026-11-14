export type Segment =
	| { kind: 'text'; text: string }
	| { kind: 'math'; tex: string; display: boolean }
	| { kind: 'code'; code: string; lang: string; block: boolean };

export const defaultCodeLang = 'lean4';

// order matters: fenced blocks before inline code, `$$` before `$`
const token =
	/```([\w-]*)[^\S\n]*\n([\s\S]*?)\n?```|(`+)([\s\S]*?[^`])\3(?!`)|\$\$([\s\S]+?)\$\$|\$((?:\\.|[^$\\\n])+?)\$|\\\$/g;

/**
 * Splits level text into prose, LaTeX, and code.
 * `$…$` is inline math and `$$…$$` display math; `\$` is a literal dollar sign.
 * `` `…` `` is inline code and ```` ```lang ```` fences a code block; code without a
 * language is Lean.
 */
export function parseRichText(source: string): Segment[] {
	const segments: Segment[] = [];
	let text = '';
	let last = 0;

	const flushText = () => {
		if (text) segments.push({ kind: 'text', text });
		text = '';
	};

	for (const match of source.matchAll(token)) {
		const [whole, fenceLang, fenceCode, , inlineCode, displayTex, inlineTex] = match;
		text += source.slice(last, match.index);
		last = match.index + whole.length;

		if (whole === '\\$') {
			text += '$';
			continue;
		}
		flushText();
		if (fenceCode !== undefined) {
			segments.push({
				kind: 'code',
				code: fenceCode,
				lang: fenceLang || defaultCodeLang,
				block: true
			});
		} else if (inlineCode !== undefined) {
			segments.push({
				kind: 'code',
				code: trimInlineCode(inlineCode),
				lang: defaultCodeLang,
				block: false
			});
		} else if (displayTex !== undefined) {
			segments.push({ kind: 'math', tex: displayTex.trim(), display: true });
		} else {
			segments.push({ kind: 'math', tex: inlineTex.trim(), display: false });
		}
	}

	text += source.slice(last);
	flushText();
	return segments;
}

/** like Markdown, one space of padding lets inline code start or end with a backtick */
function trimInlineCode(code: string) {
	return /^ .*[^ ].* $/s.test(code) ? code.slice(1, -1) : code;
}
