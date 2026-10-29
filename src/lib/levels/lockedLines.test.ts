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

test('a caret on a locked line moves past it in the direction it was going', () => {
	const locked = new Set([1, 3, 4]);
	assert.deepEqual(nearestFreeLine(2, 1, 6, locked), { line: 2, atEnd: false });
	assert.deepEqual(nearestFreeLine(3, 1, 6, locked), { line: 5, atEnd: false });
	assert.deepEqual(nearestFreeLine(4, -1, 6, locked), { line: 2, atEnd: true });
	assert.deepEqual(nearestFreeLine(1, -1, 6, locked), { line: 2, atEnd: false });
	assert.equal(nearestFreeLine(1, 1, 1, new Set([1])), null);
});

// "import Distill" occupies offsets 0–14 and is followed by a newline.
const locked = [{ from: 0, to: 14 }];

test('typing, deleting or merging into a locked line is rejected', () => {
	for (const change of [
		{ from: 3, to: 3, inserted: 'x' },
		{ from: 0, to: 0, inserted: 'x' },
		{ from: 14, to: 14, inserted: 'x' },
		{ from: 13, to: 14, inserted: '' },
		{ from: 14, to: 15, inserted: '' },
		{ from: 0, to: 20, inserted: '' }
	]) {
		assert.equal(changeKeepsLines(change, locked), false, JSON.stringify(change));
	}
});

test('new lines around a locked line and edits elsewhere are allowed', () => {
	for (const change of [
		{ from: 14, to: 14, inserted: '\n' },
		{ from: 0, to: 0, inserted: '-- hi\n' },
		{ from: 15, to: 15, inserted: 'x' },
		{ from: 15, to: 20, inserted: '' }
	]) {
		assert.equal(changeKeepsLines(change, locked), true, JSON.stringify(change));
	}
});
