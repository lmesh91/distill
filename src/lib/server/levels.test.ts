import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ObjectId } from 'mongodb';
import { getPublishedLevelBySlug } from './levels.ts';
import { getInitialCode } from '../levels/initialCode.ts';

type Levels = Parameters<typeof getPublishedLevelBySlug>[0];

const _id = new ObjectId();
const parentId = new ObjectId();
const level = {
	_id,
	parentId,
	order: 3,
	slug: 'w1-3',
	title: 'Addition is commutative',
	description: 'Prove a + b = b + a',
	type: 'guided',
	statement: 'a + b = b + a',
	starterCode: 'theorem add_comm (a b : Nat) : a + b = b + a := by\n  sorry\n',
	published: true,
	createdAt: new Date(),
	updatedAt: new Date()
};

function fakeLevels(result: unknown) {
	const filters: unknown[] = [];
	const levels = {
		findOne: async (filter: unknown) => {
			filters.push(filter);
			return result;
		}
	} as unknown as Levels;
	return { levels, filters };
}

test('a published level is returned with string ids and no timestamps', async () => {
	const { levels, filters } = fakeLevels(level);
	const data = await getPublishedLevelBySlug(levels, 'w1-3');
	assert.deepEqual(filters, [{ slug: 'w1-3', published: true }]);
	assert.deepEqual(data, {
		id: _id.toHexString(),
		parentId: parentId.toHexString(),
		slug: 'w1-3',
		order: 3,
		title: level.title,
		description: level.description,
		type: 'guided',
		statement: level.statement,
		starterCode: level.starterCode,
		expectedGoal: undefined,
		hints: []
	});
});

test('missing or unpublished levels return null', async () => {
	const { levels } = fakeLevels(null);
	assert.equal(await getPublishedLevelBySlug(levels, 'w1-3'), null);
});

test('from-scratch levels open with their target and editable starter declaration', async () => {
	const starterCode = 'import Distill\n\ntheorem identity (P : Prop) : P → P := by\n  sorry\n';
	const { levels } = fakeLevels({
		...level,
		type: 'from-scratch',
		statement: 'For every proposition P, prove that P implies P.',
		description: 'Construct a proof of the implication.',
		starterCode
	});
	const data = await getPublishedLevelBySlug(levels, level.slug);
	assert.ok(data);
	assert.equal(data.type, 'from-scratch');
	assert.equal(data.statement, 'For every proposition P, prove that P implies P.');
	assert.equal(data.description, 'Construct a proof of the implication.');
	assert.equal(getInitialCode(data), starterCode);
	assert.equal(getInitialCode(data, { status: 'not_started', currentCode: '' }), starterCode);

	const proof = starterCode.replace('sorry', 'intro h\n  assumption');
	assert.equal(getInitialCode(data, { status: 'in_progress', currentCode: proof }), proof);
	assert.equal(getInitialCode(data, { status: 'in_progress', currentCode: '' }), '');
});
