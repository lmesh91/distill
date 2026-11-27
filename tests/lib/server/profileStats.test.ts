import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ObjectId } from 'mongodb';
import { getProfileStats, summarizeProgress } from '../../../src/lib/server/profileStats.ts';

const level = (slug: string) => ({ _id: new ObjectId(), slug, title: `Title ${slug}` });
const at = (iso: string) => new Date(`2026-11-27T${iso}Z`);

test('the profile counts completed and started levels out of the published ones', () => {
	const [a, b, c] = [level('a'), level('b'), level('c')];
	const stats = summarizeProgress(
		[a, b, c],
		[
			{ levelId: a._id, status: 'completed', attemptCount: 4, completedAt: at('10:05:00') },
			{ levelId: b._id, status: 'in_progress', attemptCount: 2 },
			{ levelId: c._id, status: 'not_started', attemptCount: 0 }
		]
	);
	assert.equal(stats.completed, 1);
	assert.equal(stats.inProgress, 1);
	assert.equal(stats.total, 3);
	assert.equal(stats.checks, 6);
});

test('each solve shows its attempts and time, oldest first', () => {
	const [a, b] = [level('a'), level('b')];
	const stats = summarizeProgress(
		[a, b],
		[
			{
				levelId: b._id,
				status: 'completed',
				attemptCount: 5,
				solveAttemptCount: 3,
				startedAt: at('11:00:00'),
				completedAt: at('11:02:30')
			},
			{
				levelId: a._id,
				status: 'completed',
				attemptCount: 1,
				solveAttemptCount: 1,
				startedAt: at('10:00:00'),
				completedAt: at('10:00:40')
			}
		]
	);
	assert.deepEqual(
		stats.solves.map(({ slug, attempts, seconds }) => ({ slug, attempts, seconds })),
		[
			{ slug: 'a', attempts: 1, seconds: 40 },
			{ slug: 'b', attempts: 3, seconds: 150 }
		]
	);
	assert.equal(stats.averageAttempts, 2);
});

test('older solves without an attempt count or start time show as unknown, not zero', () => {
	const a = level('a');
	const stats = summarizeProgress(
		[a],
		[{ levelId: a._id, status: 'completed', attemptCount: 2, completedAt: at('10:00:00') }]
	);
	assert.deepEqual(
		{ attempts: stats.solves[0].attempts, seconds: stats.solves[0].seconds },
		{ attempts: null, seconds: null }
	);
	assert.equal(stats.averageAttempts, null);
});

test('progress on unpublished levels is left out', () => {
	const stats = summarizeProgress(
		[level('a')],
		[{ levelId: new ObjectId(), status: 'completed', attemptCount: 9, completedAt: new Date() }]
	);
	assert.equal(stats.completed, 0);
	assert.equal(stats.checks, 0);
});

test('only published levels and this user’s progress are read', async () => {
	const calls: unknown[] = [];
	const collection = {
		find: (filter: unknown) => {
			calls.push(filter);
			return { toArray: async () => [] };
		}
	};
	await getProfileStats(collection as never, collection as never, 'user_1');
	assert.deepEqual(calls, [{ published: true }, { userId: 'user_1' }]);
});
