import {
	HighlightStyle,
	StreamLanguage,
	syntaxHighlighting,
	type StreamParser,
	type StringStream
} from '@codemirror/language';
import { tags } from '@lezer/highlight';
import type { Extension } from '@codemirror/state';

/**
 * Lean syntax highlighting for the level editor (#69). this is a light tokenizer, not a parser:
 * it colors keywords, tactics, types, comments, strings, numbers and operators line by line,
 * which is enough for the proofs learners write. Lean's own errors still come from the server
 */

/** commands and term-level keywords */
const keywords = new Set([
	'theorem',
	'lemma',
	'def',
	'example',
	'instance',
	'structure',
	'class',
	'inductive',
	'where',
	'abbrev',
	'axiom',
	'variable',
	'universe',
	'namespace',
	'section',
	'end',
	'open',
	'import',
	'export',
	'set_option',
	'attribute',
	'deriving',
	'mutual',
	'private',
	'protected',
	'noncomputable',
	'partial',
	'unsafe',
	'notation',
	'infix',
	'infixl',
	'infixr',
	'prefix',
	'postfix',
	'macro',
	'macro_rules',
	'syntax',
	'elab',
	'by',
	'fun',
	'λ',
	'let',
	'have',
	'show',
	'from',
	'at',
	'with',
	'match',
	'do',
	'if',
	'then',
	'else',
	'in',
	'return',
	'for',
	'calc',
	'suffices',
	'termination_by',
	'decreasing_by'
]);

/** tactics, colored apart from keywords so proof steps stand out */
const tactics = new Set([
	'intro',
	'intros',
	'rintro',
	'exact',
	'apply',
	'refine',
	'constructor',
	'cases',
	'rcases',
	'obtain',
	'induction',
	'simp',
	'simp_all',
	'dsimp',
	'rw',
	'rewrite',
	'rwa',
	'rfl',
	'assumption',
	'use',
	'exists',
	'existsi',
	'left',
	'right',
	'unfold',
	'specialize',
	'contradiction',
	'exfalso',
	'trivial',
	'omega',
	'linarith',
	'nlinarith',
	'norm_num',
	'ring',
	'decide',
	'aesop',
	'ext',
	'funext',
	'congr',
	'subst',
	'by_contra',
	'by_cases',
	'split',
	'exact?',
	'apply?',
	'first',
	'repeat',
	'try',
	'all_goals',
	'any_goals',
	'focus',
	'next',
	'case',
	'change',
	'generalize',
	'clear',
	'revert',
	'symm',
	'trans',
	'injection',
	'nofun',
	'nomatch',
	'tauto',
	'positivity'
]);

/** proofs left unfinished; colored as a warning */
const unfinished = new Set(['sorry', 'admit']);

const types = new Set(['Type', 'Prop', 'Sort']);

// a name part: a letter or underscore, then letters, digits, subscripts, primes, ! and ?
const namePart = String.raw`[\p{L}_][\p{L}\p{N}_'!?₀-ₜᵢ-ᵪ]*`;
// a dotted name like `hx.left` or `Nat.succ_le`; Lean also allows `h.1`
const name = new RegExp(String.raw`^${namePart}(?:\.(?:${namePart}|\d+))*`, 'u');

const number = /^(?:0x[0-9a-fA-F]+|0b[01]+|\d+(?:\.\d+)?)/;

// longest first, so `:=` wins over `:` and `<->` over `<-`
const operator =
	/^(?::=|<->|->|<-|=>|<=|>=|!=|==|&&|\|\||[→←↔⇒∀∃∄∧∨¬∈∉⊆⊂⊇⊃∩∪∘×≠≤≥≈≡∣·•⁻¹]|[+\-*/=<>%^&!~:|$])/u;

interface LeanState {
	/** how many `/-` comments are open; Lean nests them */
	commentDepth: number;
	/** inside a string that continues on the next line */
	inString: boolean;
}

function blockComment(stream: StringStream, state: LeanState): string {
	while (!stream.eol()) {
		if (stream.match('-/')) {
			state.commentDepth--;
			if (state.commentDepth === 0) return 'comment';
		} else if (stream.match('/-')) {
			state.commentDepth++;
		} else {
			stream.next();
		}
	}
	return 'comment';
}

function string(stream: StringStream, state: LeanState): string {
	while (!stream.eol()) {
		const ch = stream.next();
		if (ch === '\\') stream.next();
		else if (ch === '"') {
			state.inString = false;
			return 'string';
		}
	}
	state.inString = true;
	return 'string';
}

export const leanStreamParser: StreamParser<LeanState> = {
	name: 'lean4',
	startState: () => ({ commentDepth: 0, inString: false }),
	copyState: (state) => ({ ...state }),
	token(stream, state) {
		if (state.commentDepth > 0) return blockComment(stream, state);
		if (state.inString) return string(stream, state);
		if (stream.eatSpace()) return null;

		if (stream.match('--')) {
			stream.skipToEnd();
			return 'comment';
		}
		if (stream.match('/-')) {
			state.commentDepth = 1;
			return blockComment(stream, state);
		}
		if (stream.eat('"')) return string(stream, state);
		// attributes like @[simp] and commands like #check
		if (stream.match(/^@\[[^\]]*\]?/) || stream.match(/^#[a-z_]+/)) return 'meta';
		if (stream.match(number)) return 'number';

		const word = stream.match(name) as RegExpMatchArray | null;
		if (word) {
			const text = word[0];
			if (unfinished.has(text)) return 'sorry';
			if (keywords.has(text)) return 'keyword';
			if (tactics.has(text)) return 'tactic';
			// `Set`, `Nat` and `Or.inl` read as types, by Lean's capitalized naming convention.
			// single capitals like `A` and `B` are left alone: the levels use them for sets
			const first = text.split('.')[0];
			if (types.has(first) || /^\p{Lu}[\p{L}\p{N}_]/u.test(first)) return 'typeName';
			return 'variableName';
		}

		if (stream.match(operator)) return 'operator';
		stream.next();
		return null;
	},
	// tactics and sorry get their own highlight tags
	tokenTable: { tactic: tags.controlKeyword, sorry: tags.invalid },
	languageData: {
		commentTokens: { line: '--', block: { open: '/-', close: '-/' } }
	}
};

export const leanLanguage = StreamLanguage.define(leanStreamParser);

/** the colors, from the design system's --color-code-* tokens so they follow the theme */
export const leanHighlightStyle = HighlightStyle.define([
	{ tag: tags.keyword, color: 'var(--color-code-keyword)' },
	{ tag: tags.controlKeyword, color: 'var(--color-code-tactic)' },
	{ tag: tags.comment, color: 'var(--color-code-comment)' },
	{ tag: tags.string, color: 'var(--color-code-string)' },
	{ tag: tags.number, color: 'var(--color-code-number)' },
	{ tag: tags.operator, color: 'var(--color-code-operator)' },
	{ tag: tags.typeName, color: 'var(--color-code-type)' },
	{ tag: tags.meta, color: 'var(--color-code-keyword)' },
	{
		tag: tags.invalid,
		color: 'var(--color-code-sorry)',
		textDecoration: 'underline wavy',
		textUnderlineOffset: '3px'
	}
]);

/** everything the editor needs for Lean highlighting */
export function lean(): Extension {
	return [leanLanguage, syntaxHighlighting(leanHighlightStyle)];
}
