import assert from 'node:assert/strict';
import { test } from 'node:test';
import { StringStream } from '@codemirror/language';
import { leanStreamParser } from '../../../src/lib/lean/language.ts';

/** runs the tokenizer over some lines and returns [text, style] for every styled token */
function tokens(source: string) {
	const state = leanStreamParser.startState!(2);
	const out: [string, string][] = [];
	for (const line of source.split('\n')) {
		const stream = new StringStream(line, 2, 2);
		while (!stream.eol()) {
			const style = leanStreamParser.token(stream, state);
			const text = line.slice(stream.start, stream.pos);
			if (style) out.push([text, style]);
			stream.start = stream.pos;
		}
	}
	return out;
}

function styleOf(source: string, text: string) {
	return tokens(source).find(([t]) => t === text)?.[1];
}

test('commands, tactics and keywords get their own colors', () => {
	const source = 'theorem foo (A B : Set α) : A ∩ B ⊆ A := by\n  intro x hx\n  exact hx.left';
	assert.equal(styleOf(source, 'theorem'), 'keyword');
	assert.equal(styleOf(source, 'by'), 'keyword');
	assert.equal(styleOf(source, 'intro'), 'tactic');
	assert.equal(styleOf(source, 'exact'), 'tactic');
	assert.equal(styleOf(source, 'Set'), 'typeName');
	assert.equal(styleOf(source, 'foo'), 'variableName');
	// the levels name sets with single capitals, which are variables, not types
	assert.equal(styleOf(source, 'A'), 'variableName');
});

test('dotted names stay one token, so hx.left is not split up', () => {
	assert.equal(styleOf('exact hx.left', 'hx.left'), 'variableName');
	assert.equal(styleOf('exact h.1', 'h.1'), 'variableName');
	assert.equal(styleOf('apply Set.subset_def', 'Set.subset_def'), 'typeName');
});

test('logic and set symbols are operators, and := wins over :', () => {
	const source = 'example : ∀ x, x ∈ A → x ∈ A ∪ B := fun x h => Or.inl h';
	for (const op of ['∀', '∈', '→', '∪', ':=', '=>'])
		assert.equal(styleOf(source, op), 'operator', op);
	assert.equal(styleOf(source, 'fun'), 'keyword');
});

test('line comments, nested block comments and strings are recognized', () => {
	assert.deepEqual(tokens('rfl -- done'), [
		['rfl', 'tactic'],
		['-- done', 'comment']
	]);
	// the inner /- -/ doesn't end the outer comment
	const nested = tokens('/- outer /- inner -/\nstill comment -/ rfl');
	assert.deepEqual(nested.at(-1), ['rfl', 'tactic']);
	assert.ok(nested.slice(0, -1).every(([, style]) => style === 'comment'));
	assert.equal(styleOf('#eval "a \\" b"', '"a \\" b"'), 'string');
	assert.equal(styleOf('#check Nat', '#check'), 'meta');
});

test('sorry is flagged so unfinished proofs stand out', () => {
	assert.equal(styleOf('  sorry', 'sorry'), 'sorry');
});

test('numbers, primes and subscripts', () => {
	assert.equal(styleOf('exact 42', '42'), 'number');
	assert.equal(styleOf("intro x'", "x'"), 'variableName');
	assert.equal(styleOf('intro h₁', 'h₁'), 'variableName');
});
