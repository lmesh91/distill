import assert from 'node:assert/strict';
import { test } from 'node:test';
import { formatDuration, levelScore } from '../../../src/lib/levels/score.ts';

test('the score uses the attempts to first solve and the time from start to first solve', () => {
	assert.deepEqual(
		levelScore({
			solveAttemptCount: 3,
			startedAt: '2026-11-27T10:00:00.000Z',
			completedAt: '2026-11-27T10:04:05.400Z'
		}),
		{ attempts: 3, seconds: 245 }
	);
});

test('missing or impossible values become null instead of a wrong number', () => {
	assert.deepEqual(levelScore(undefined), { attempts: null, seconds: null });
	// completed before the attempt count was recorded
	assert.deepEqual(levelScore({ completedAt: new Date(0), startedAt: new Date(0) }), {
		attempts: null,
		seconds: 0
	});
	// clocks that disagree
	assert.equal(
		levelScore({ startedAt: '2026-11-27T10:00:00Z', completedAt: '2026-11-27T09:00:00Z' }).seconds,
		null
	);
	assert.equal(levelScore({ startedAt: 'not a date', completedAt: new Date() }).seconds, null);
});

test('durations read naturally at every scale', () => {
	assert.equal(formatDuration(0), '0s');
	assert.equal(formatDuration(45), '45s');
	assert.equal(formatDuration(185), '3m 05s');
	assert.equal(formatDuration(3720), '1h 02m');
});
