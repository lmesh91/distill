import assert from 'node:assert/strict';
import { test } from 'node:test';
import { changeKeepsLines, findLockedLines, nearestFreeLine } from './lockedLines.ts';

const starter = 'import Distill\n\nexample : 1 + 1 = 2 := by\n  sorry\n';

test('locked lines are found in the starter code itself', () => {
	assert.deepEqual(findLockedLines(starter, [3, 1], starter), [1, 3]);
});

test('locked lines follow their text in saved code and are dropped once removed', () => {
	const saved = 'import Distill\n-- notes\n\nexample : 1 + 1 = 2 := by\n  rfl\n';
	assert.deepEqual(findLockedLines(starter, [1, 3], saved), [1, 4]);
	assert.deepEqual(findLockedLines(starter, [1, 3], 'example : 1 + 1 = 2 := by\n  rfl'), [1]);
	assert.deepEqual(findLockedLines(starter, [99], starter), []);
});

test('repeated lines lock the intended occurrence', () => {
	const repeated = 'import Distill\n\nexample : True := by\n  trivial\n\n';
	assert.deepEqual(findLockedLines(repeated, [1, 5], repeated), [1, 5]);
	const saved = 'import Distill\n\nexample : True := by\n  trivial\n  -- done\n\n';
	assert.deepEqual(findLockedLines(repeated, [1, 5], saved), [1, 6]);
	const twice = 'a\nb\na\nb\n';
	assert.deepEqual(findLockedLines(twice, [3], 'a\nb\nx\na\nb\n'), [4]);
});

test('a caret on a locked line moves past it in the direction it was going', () => {
	const locked = new Set([1, 3, 4]);
	assert.deepEqual(nearestFreeLine(2, 1, 6, locked), { line: 2, atEnd: false });
	assert.deepEqual(nearestFreeLine(3, 1, 6, locked), { line: 5, atEnd: false });
	assert.deepEqual(nearestFreeLine(4, -1, 6, locked), { line: 2, atEnd: true });
	assert.deepEqual(nearestFreeLine(1, -1, 6, locked), { line: 2, atEnd: false });
	assert.equal(nearestFreeLine(1, 1, 1, new Set([1])), null);
});

// In `starter`, "import Distill" occupies offsets 0–14, a blank line is at 15, and the example
// occupies 16–41.
const locked = [
	{ from: 0, to: 14 },
	{ from: 16, to: 41 }
];

test('typing, deleting or merging into a locked line is rejected', () => {
	for (const change of [
		{ from: 3, to: 3, inserted: 'x' },
		{ from: 0, to: 0, inserted: 'x' },
		{ from: 14, to: 14, inserted: 'x' },
		{ from: 13, to: 14, inserted: '' },
		{ from: 14, to: 16, inserted: '' },
		{ from: 15, to: 16, inserted: 'x' },
		{ from: 0, to: 20, inserted: '' }
	]) {
		assert.equal(changeKeepsLines(change, locked, starter), false, JSON.stringify(change));
	}
});

test('new lines around a locked line and edits elsewhere are allowed', () => {
	for (const change of [
		{ from: 14, to: 14, inserted: '\n' },
		{ from: 0, to: 0, inserted: '-- hi\n' },
		{ from: 15, to: 15, inserted: 'x' },
		{ from: 42, to: 49, inserted: '' }
	]) {
		assert.equal(changeKeepsLines(change, locked, starter), true, JSON.stringify(change));
	}
});

test('whole unlocked lines next to a locked line can be removed', () => {
	assert.equal(changeKeepsLines({ from: 15, to: 16, inserted: '' }, locked, starter), true);
	assert.equal(changeKeepsLines({ from: 14, to: 15, inserted: '' }, locked, starter), true);
	const withComment = 'import Distill\n-- note\nexample : True := by\n  trivial\n';
	const ranges = [
		{ from: 0, to: 14 },
		{ from: 23, to: 43 }
	];
	assert.equal(changeKeepsLines({ from: 15, to: 23, inserted: '' }, ranges, withComment), true);
	assert.equal(changeKeepsLines({ from: 16, to: 23, inserted: '' }, ranges, withComment), false);
});
