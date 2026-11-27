import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ObjectId } from 'mongodb';
import {
	getLevelSelect,
	inPlayOrder,
	nextUnfinished,
	type LevelSelectEntry
} from '../../../src/lib/server/levelSelect.ts';

type Levels = Parameters<typeof getLevelSelect>[0];
type Progress = Parameters<typeof getLevelSelect>[1];

function level(slug: string, order: number, parentId?: ObjectId) {
	return { _id: new ObjectId(), slug, order, parentId, title: `Title ${slug}`, type: 'guided' };
}

function slugs(levels: { slug: string }[]) {
	return levels.map((l) => l.slug);
}

function fakeCollection(docs: unknown[]) {
	const calls: unknown[][] = [];
	const collection = {
		find: (...args: unknown[]) => {
			calls.push(args);
			return { toArray: async () => docs };
		}
	};
	return { collection, calls };
}

test('roots are ordered by `order`, whatever order the database returns them in', () => {
	const levels = [level('c', 3), level('a', 1), level('b', 2)];
	assert.deepEqual(slugs(inPlayOrder(levels)), ['a', 'b', 'c']);
});

test('a level is followed by its children before its next sibling', () => {
	const root = level('root', 1);
	const second = level('second', 2);
	const child2 = level('child-2', 2, root._id);
	const child1 = level('child-1', 1, root._id);
	const grandchild = level('grandchild', 1, child1._id);
	const levels = [second, child2, grandchild, root, child1];
	assert.deepEqual(slugs(inPlayOrder(levels)), [
		'root',
		'child-1',
		'grandchild',
		'child-2',
		'second'
	]);
});

test('a level whose parent is missing or unpublished still shows up, as a root', () => {
	const orphan = level('orphan', 2, new ObjectId());
	assert.deepEqual(slugs(inPlayOrder([orphan, level('first', 1)])), ['first', 'orphan']);
});

test('siblings with the same order fall back to slug order', () => {
	assert.deepEqual(slugs(inPlayOrder([level('b', 1), level('a', 1)])), ['a', 'b']);
});

test('a parent cycle in bad data does not loop forever or drop the levels outside it', () => {
	const a = level('a', 1);
	const b = level('b', 1, a._id);
	a.parentId = b._id;
	assert.deepEqual(slugs(inPlayOrder([a, b, level('ok', 1)])), ['ok']);
});

test('levels come back numbered in play order with the user’s status on each', async () => {
	const first = level('first', 1);
	const second = level('second', 2);
	const third = level('third', 3);
	const levels = fakeCollection([third, first, second]);
	const progress = fakeCollection([
		{ levelId: first._id, status: 'completed' },
		{ levelId: second._id, status: 'in_progress' }
	]);

	const entries = await getLevelSelect(
		levels.collection as unknown as Levels,
		progress.collection as unknown as Progress,
		'user_1'
	);

	assert.deepEqual(entries, [
		{ number: 1, slug: 'first', title: 'Title first', type: 'guided', status: 'completed' },
		{ number: 2, slug: 'second', title: 'Title second', type: 'guided', status: 'in_progress' },
		{ number: 3, slug: 'third', title: 'Title third', type: 'guided', status: 'not_started' }
	]);
});

test('only published levels and only this user’s progress are read', async () => {
	const levels = fakeCollection([]);
	const progress = fakeCollection([]);
	await getLevelSelect(
		levels.collection as unknown as Levels,
		progress.collection as unknown as Progress,
		'user_1'
	);
	assert.deepEqual((levels.calls[0] as unknown[])[0], { published: true });
	assert.deepEqual((progress.calls[0] as unknown[])[0], { userId: 'user_1' });
});

test('continue points at the first level in play order that is not completed', () => {
	const entry = (number: number, status: LevelSelectEntry['status']): LevelSelectEntry => ({
		number,
		slug: `l${number}`,
		title: '',
		type: 'guided',
		status
	});
	assert.equal(
		nextUnfinished([entry(1, 'completed'), entry(2, 'not_started'), entry(3, 'in_progress')])?.slug,
		'l2'
	);
	assert.equal(nextUnfinished([entry(1, 'completed')]), undefined);
});
