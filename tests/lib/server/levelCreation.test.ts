import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MongoServerError, ObjectId } from 'mongodb';
import { createLevel } from '../../../src/lib/server/levelCreation.ts';
import type { NewLevelInput } from '../../../src/lib/admin/levelForm.ts';

const input: NewLevelInput = {
	title: 'Subset is reflexive',
	slug: 'subset_rfl',
	description: 'Show it.',
	type: 'hints',
	statement: 'A ⊆ A',
	starterCode: 'import Distill',
	lockedLines: [],
	hints: [],
	verification: { theoremName: 'subset_rfl', challengeSource: 'theorem subset_rfl' },
	order: 0,
	published: false
};

function fakeLevels({
	parent = true,
	insertError
}: { parent?: boolean; insertError?: Error } = {}) {
	const inserted: unknown[] = [];
	return {
		inserted,
		levels: {
			findOne: async () => (parent ? { _id: new ObjectId() } : null),
			insertOne: async (doc: unknown) => {
				if (insertError) throw insertError;
				inserted.push(doc);
				return { acknowledged: true, insertedId: new ObjectId() };
			}
		}
	};
}

test('a new level is saved with timestamps and without empty optional fields', async () => {
	const { levels, inserted } = fakeLevels();
	const now = new Date('2026-11-27T12:00:00Z');
	assert.deepEqual(await createLevel(levels as never, input, now), {
		ok: true,
		slug: 'subset_rfl'
	});
	const doc = inserted[0] as Record<string, unknown>;
	assert.equal(doc.createdAt, now);
	assert.equal(doc.updatedAt, now);
	for (const field of ['parentId', 'lockedLines', 'expectedGoal', 'targetProof']) {
		assert.equal(field in doc, false, field);
	}
});

test('a parent level is stored as an ObjectId after checking it exists', async () => {
	const parentId = new ObjectId().toHexString();
	const { levels, inserted } = fakeLevels();
	await createLevel(levels as never, { ...input, parentId });
	assert.equal(String((inserted[0] as { parentId: ObjectId }).parentId), parentId);

	const missing = fakeLevels({ parent: false });
	assert.deepEqual(await createLevel(missing.levels as never, { ...input, parentId }), {
		ok: false,
		reason: 'parent_missing'
	});
	assert.equal(missing.inserted.length, 0);
});

test('a taken slug is reported instead of throwing', async () => {
	const duplicate = new MongoServerError({ message: 'E11000 duplicate key', code: 11000 });
	const { levels } = fakeLevels({ insertError: duplicate });
	assert.deepEqual(await createLevel(levels as never, input), { ok: false, reason: 'slug_taken' });
	const other = fakeLevels({ insertError: new Error('network') });
	await assert.rejects(createLevel(other.levels as never, input), /network/);
});
