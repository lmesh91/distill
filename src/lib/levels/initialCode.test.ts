import assert from 'node:assert/strict';
import { test } from 'node:test';
import { getInitialCode } from './initialCode.ts';

const level = { starterCode: 'theorem one_add_one : 1 + 1 = 2 := by\n  sorry\n' };

test('a level with no progress record starts with its starter code', () => {
	assert.equal(getInitialCode(level, null), level.starterCode);
	assert.equal(getInitialCode(level, undefined), level.starterCode);
	assert.equal(getInitialCode(level), level.starterCode);
});

test('a level marked not_started starts with its starter code', () => {
	assert.equal(
		getInitialCode(level, { status: 'not_started', currentCode: '' }),
		level.starterCode
	);
});

test('a level with saved work shows the saved code', () => {
	const saved = 'theorem one_add_one : 1 + 1 = 2 := by\n  rfl\n';
	assert.equal(getInitialCode(level, { status: 'in_progress', currentCode: saved }), saved);
	assert.equal(getInitialCode(level, { status: 'completed', currentCode: saved }), saved);
});

test('saved work that the user cleared stays empty instead of resetting', () => {
	assert.equal(getInitialCode(level, { status: 'in_progress', currentCode: '' }), '');
});
