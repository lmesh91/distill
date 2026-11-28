import assert from 'node:assert/strict';
import { test } from 'node:test';
import { parseLevelForm, slugify } from '../../../src/lib/admin/levelForm.ts';

const valid = {
	title: 'Subset is reflexive',
	slug: 'subset_rfl',
	description: 'Show that every set is a subset of itself.',
	type: 'hints',
	statement: 'For every set $A$, $A \\subseteq A$.',
	starterCode: 'import Distill\r\n\r\ntheorem subset_rfl (A : Set α) : A ⊆ A := by\r\n  sorry\r\n',
	lockedLines: '1',
	hints: 'Start with intro.\n\n  Then use the hypothesis.  \n',
	theoremName: 'subset_rfl',
	challengeSource: 'import Distill\ntheorem subset_rfl (A : Set α) : A ⊆ A := by sorry\n',
	parentId: '',
	order: '2',
	published: 'on'
};

function form(overrides: Record<string, string | null> = {}) {
	const data = new FormData();
	for (const [key, value] of Object.entries({ ...valid, ...overrides })) {
		if (value !== null) data.set(key, value);
	}
	return data;
}

test('a complete form becomes a level, with line endings and hints cleaned up', () => {
	const result = parseLevelForm(form());
	assert.ok(result.ok);
	assert.equal(
		result.level.starterCode,
		'import Distill\n\ntheorem subset_rfl (A : Set α) : A ⊆ A := by\n  sorry'
	);
	assert.deepEqual(result.level.hints, ['Start with intro.', 'Then use the hypothesis.']);
	assert.deepEqual(result.level.lockedLines, [1]);
	assert.equal(result.level.order, 2);
	assert.equal(result.level.published, true);
	assert.equal(result.level.parentId, undefined);
	assert.deepEqual(result.level.verification, {
		theoremName: 'subset_rfl',
		challengeSource: valid.challengeSource.trimEnd()
	});
});

test('every missing required field is reported at once', () => {
	const result = parseLevelForm(
		form({
			title: '',
			description: ' ',
			statement: '',
			starterCode: '',
			theoremName: '',
			challengeSource: ''
		})
	);
	assert.equal(result.ok, false);
	if (result.ok) return;
	assert.deepEqual(Object.keys(result.errors).sort(), [
		'challengeSource',
		'description',
		'starterCode',
		'statement',
		'theoremName',
		'title'
	]);
	// the form keeps what the admin typed
	assert.equal(result.values.slug, 'subset_rfl');
});

test('slugs must be lowercase words joined by - or _', () => {
	for (const slug of ['Subset', 'subset rfl', '-subset', 'subset__rfl', '']) {
		const result = parseLevelForm(form({ slug }));
		assert.equal(result.ok, false, slug);
		if (!result.ok) assert.ok(result.errors.slug, slug);
	}
	assert.ok(parseLevelForm(form({ slug: 'hello-world' })).ok);
});

test('guided levels need the English proof learners match', () => {
	const result = parseLevelForm(form({ type: 'guided' }));
	assert.equal(result.ok, false);
	if (!result.ok) assert.ok(result.errors.targetProof);
	assert.ok(
		parseLevelForm(form({ type: 'guided', targetProof: 'Let $x \\in A$. Then $x \\in A$.' })).ok
	);
	const unknown = parseLevelForm(form({ type: 'puzzle' }));
	assert.equal(unknown.ok, false);
});

test('the challenge has to declare the theorem that submissions are checked against', () => {
	const result = parseLevelForm(form({ theoremName: 'other_name' }));
	assert.equal(result.ok, false);
	if (!result.ok) assert.match(result.errors.challengeSource ?? '', /other_name/);
	// a namespaced name matches a theorem declared inside the namespace
	const namespaced = parseLevelForm(
		form({
			theoremName: 'Exercise.subset_rfl',
			challengeSource: 'namespace Exercise\ntheorem subset_rfl : True := by sorry\nend Exercise'
		})
	);
	assert.ok(namespaced.ok);
	assert.equal(parseLevelForm(form({ theoremName: 'not a name' })).ok, false);
});

test('locked lines must be real lines of the starter code', () => {
	const tooFar = parseLevelForm(form({ lockedLines: '1, 9' }));
	assert.equal(tooFar.ok, false);
	if (!tooFar.ok) assert.match(tooFar.errors.lockedLines ?? '', /4 lines/);
	assert.equal(parseLevelForm(form({ lockedLines: '0' })).ok, false);
	const many = parseLevelForm(form({ lockedLines: '3 1, 1' }));
	assert.ok(many.ok && many.level.lockedLines.join() === '1,3');
});

test('order and parent are checked, and unchecked publish means a draft', () => {
	assert.equal(parseLevelForm(form({ order: '-1' })).ok, false);
	assert.equal(parseLevelForm(form({ order: '1.5' })).ok, false);
	assert.equal(parseLevelForm(form({ parentId: 'nope' })).ok, false);
	const draft = parseLevelForm(form({ published: null, order: '' }));
	assert.ok(draft.ok && draft.level.published === false && draft.level.order === 0);
});

test('slugify suggests a slug from the title', () => {
	assert.equal(slugify('Subset is reflexive!'), 'subset-is-reflexive');
	assert.equal(slugify('  Café ∩ Sets  '), 'cafe-sets');
	assert.equal(slugify('∀∃'), '');
});
