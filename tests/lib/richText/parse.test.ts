import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseRichText } from '../../../src/lib/richText/parse.ts';

test('plain text is a single segment', () => {
	assert.deepEqual(parseRichText('Prove it.'), [{ kind: 'text', text: 'Prove it.' }]);
});

test('inline and display math', () => {
	assert.deepEqual(parseRichText('Show $a + b = b + a$ for all\n$$ n \\in \\mathbb{N} $$'), [
		{ kind: 'text', text: 'Show ' },
		{ kind: 'math', tex: 'a + b = b + a', display: false },
		{ kind: 'text', text: ' for all\n' },
		{ kind: 'math', tex: 'n \\in \\mathbb{N}', display: true }
	]);
});

test('escaped and unmatched dollar signs stay literal', () => {
	assert.deepEqual(parseRichText('costs \\$5 or $3'), [{ kind: 'text', text: 'costs $5 or $3' }]);
});

test('inline math does not span lines', () => {
	assert.deepEqual(parseRichText('$a\nb$'), [{ kind: 'text', text: '$a\nb$' }]);
});

test('inline code defaults to Lean', () => {
	assert.deepEqual(parseRichText('Use `Nat.add_comm` here'), [
		{ kind: 'text', text: 'Use ' },
		{ kind: 'code', code: 'Nat.add_comm', lang: 'lean4', block: false },
		{ kind: 'text', text: ' here' }
	]);
});

test('double backticks allow a backtick inside inline code', () => {
	assert.deepEqual(parseRichText('`` a`b ``'), [
		{ kind: 'code', code: 'a`b', lang: 'lean4', block: false }
	]);
});

test('dollar signs inside code are not math', () => {
	assert.deepEqual(parseRichText('`f $ x $ y`'), [
		{ kind: 'code', code: 'f $ x $ y', lang: 'lean4', block: false }
	]);
});

test('fenced code blocks keep their language', () => {
	assert.deepEqual(parseRichText('Try:\n```lean\nintro h\nexact h\n```\ndone'), [
		{ kind: 'text', text: 'Try:\n' },
		{ kind: 'code', code: 'intro h\nexact h', lang: 'lean', block: true },
		{ kind: 'text', text: '\ndone' }
	]);
	assert.deepEqual(parseRichText('```\nrfl\n```'), [
		{ kind: 'code', code: 'rfl', lang: 'lean4', block: true }
	]);
});
