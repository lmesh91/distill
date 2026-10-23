import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ObjectId } from 'mongodb';
import { getSavedProgress } from '../../../src/lib/server/progress.ts';

type Progress = Parameters<typeof getSavedProgress>[0];

test('returns only the saved code, status and save time for this user and level', async () => {
	const levelId = new ObjectId();
	const clientSavedAt = new Date('2026-10-22T12:00:00Z');
	const queries: unknown[] = [];
	const progress = {
		findOne: async (filter: unknown, options: unknown) => {
			queries.push({ filter, options });
			return { status: 'in_progress', currentCode: 'rfl', clientSavedAt, attemptCount: 3 };
		}
	} as unknown as Progress;

	assert.deepEqual(await getSavedProgress(progress, 'user-1', levelId), {
		status: 'in_progress',
		currentCode: 'rfl',
		clientSavedAt
	});
	assert.deepEqual(queries, [
		{
			filter: { userId: 'user-1', levelId },
			options: { projection: { _id: 0, status: 1, currentCode: 1, clientSavedAt: 1 } }
		}
	]);
});

test('returns null when the user has not worked on the level', async () => {
	const progress = { findOne: async () => null } as unknown as Progress;
	assert.equal(await getSavedProgress(progress, 'user-1', new ObjectId()), null);
});
