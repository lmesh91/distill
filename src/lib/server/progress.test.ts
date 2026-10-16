import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MongoServerError, ObjectId } from 'mongodb';
import { saveLevelProgress } from './progress.ts';

const levelId = new ObjectId();
const clientSavedAt = new Date('2026-10-15T12:00:00Z');
const input = { userId: 'user-1', levelId, code: 'example : True := trivial', clientSavedAt };

type Levels = Parameters<typeof saveLevelProgress>[0];
type Progress = Parameters<typeof saveLevelProgress>[1];
type UpdateArgs = Parameters<Progress['updateOne']>;

function fakes({
	levelExists = true,
	updateError
}: { levelExists?: boolean; updateError?: Error } = {}) {
	const calls: { filter: UpdateArgs[0]; update: UpdateArgs[1]; options: UpdateArgs[2] }[] = [];
	const levels = {
		findOne: async (filter: unknown) => {
			assert.deepEqual(filter, { _id: levelId, published: true });
			return levelExists ? { _id: levelId } : null;
		}
	} as unknown as Levels;
	const progress = {
		updateOne: async (...[filter, update, options]: UpdateArgs) => {
			calls.push({ filter, update, options });
			if (updateError) throw updateError;
			return { acknowledged: true, matchedCount: 1, modifiedCount: 1, upsertedCount: 0 };
		}
	} as unknown as Progress;
	return { levels, progress, calls };
}

test('saves are scoped to one user and level and only apply when newer', async () => {
	const { levels, progress, calls } = fakes();
	assert.equal(await saveLevelProgress(levels, progress, input), 'saved');
	assert.equal(calls.length, 1);
	const [{ filter, options }] = calls;
	assert.deepEqual(filter, {
		userId: 'user-1',
		levelId,
		$or: [{ clientSavedAt: { $lt: clientSavedAt } }, { clientSavedAt: { $exists: false } }]
	});
	assert.deepEqual(options, { upsert: true });
});

test('code and timestamps are literals and completed status is preserved', async () => {
	const { levels, progress, calls } = fakes();
	await saveLevelProgress(levels, progress, { ...input, code: '$status' });
	const [stage] = calls[0].update as { $set: Record<string, unknown> }[];
	const set = stage.$set as Record<string, { $ifNull?: unknown[] }>;
	assert.deepEqual(set.currentCode, { $literal: '$status' });
	assert.deepEqual(set.clientSavedAt, { $literal: clientSavedAt });
	assert.deepEqual(set.status, {
		$cond: [{ $eq: ['$status', 'completed'] }, 'completed', 'in_progress']
	});
	assert.deepEqual(set.attemptCount, { $ifNull: ['$attemptCount', 0] });
	assert.equal(set.startedAt.$ifNull?.[0], '$startedAt');
	for (const field of ['completedAt', 'currentError', 'lastAttemptedAt']) {
		assert.equal(field in set, false, `${field} should not be touched by saves`);
	}
});

test('missing or unpublished levels are not saved', async () => {
	const { levels, progress, calls } = fakes({ levelExists: false });
	assert.equal(await saveLevelProgress(levels, progress, input), 'level_not_found');
	assert.equal(calls.length, 0);
});

test('an older save that collides with a newer record is reported as stale', async () => {
	const updateError = new MongoServerError({ message: 'E11000 duplicate key', code: 11000 });
	const { levels, progress } = fakes({ updateError });
	assert.equal(await saveLevelProgress(levels, progress, input), 'stale');
});

test('other database errors are rethrown', async () => {
	const updateError = new MongoServerError({ message: 'boom', code: 1 });
	const { levels, progress } = fakes({ updateError });
	await assert.rejects(saveLevelProgress(levels, progress, input), updateError);
});
