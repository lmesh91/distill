import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ObjectId } from 'mongodb';
import { getNextLevelSlug } from '../../../src/lib/server/levels.ts';

type Levels = Parameters<typeof getNextLevelSlug>[0];

const id = new ObjectId();
const parentId = new ObjectId();
const level = { id: id.toHexString(), parentId: parentId.toHexString(), order: 2 };

function fakeLevels(results: ({ slug: string } | null)[]) {
	const calls: { filter: unknown; options: unknown }[] = [];
	const levels = {
		findOne: async (filter: unknown, options: unknown) => {
			calls.push({ filter, options });
			return results.shift() ?? null;
		}
	} as unknown as Levels;
	return { levels, calls };
}

const options = { sort: { order: 1 }, projection: { _id: 0, slug: 1 } };

test('offers the first published level this one unlocks', async () => {
	const { levels, calls } = fakeLevels([{ slug: 'w1-3a' }]);
	assert.equal(await getNextLevelSlug(levels, level), 'w1-3a');
	assert.deepEqual(calls, [{ filter: { parentId: id, published: true }, options }]);
});

test('falls back to the next published sibling', async () => {
	const { levels, calls } = fakeLevels([null, { slug: 'w1-3' }]);
	assert.equal(await getNextLevelSlug(levels, level), 'w1-3');
	assert.deepEqual(calls[1], {
		filter: { parentId, order: { $gt: 2 }, published: true },
		options
	});
});

test('root levels look for the next root level', async () => {
	const { levels, calls } = fakeLevels([null, null]);
	assert.equal(await getNextLevelSlug(levels, { id: level.id, order: 1 }), null);
	assert.deepEqual(calls[1].filter, {
		parentId: { $exists: false },
		order: { $gt: 1 },
		published: true
	});
});
