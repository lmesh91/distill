import { MongoServerError, ObjectId, type Collection } from 'mongodb';
import type { NewLevelInput } from '$lib/admin/levelForm';
import type { Level } from '$lib/types/level';

/**
 * saves a level from the administrator form (#40). this is the smallest backend the form needs;
 * the level-creation operation in #42 can replace it
 */
export type CreateLevelResult =
	{ ok: true; slug: string } | { ok: false; reason: 'slug_taken' | 'parent_missing' };

const duplicateKeyErrorCode = 11000;

export async function createLevel(
	levels: Pick<Collection<Level>, 'insertOne' | 'findOne'>,
	input: NewLevelInput,
	now = new Date()
): Promise<CreateLevelResult> {
	let parentId: ObjectId | undefined;
	if (input.parentId) {
		// parseLevelForm already checks this, but other callers (#42) might not
		if (!ObjectId.isValid(input.parentId)) return { ok: false, reason: 'parent_missing' };
		parentId = new ObjectId(input.parentId);
		const parent = await levels.findOne({ _id: parentId }, { projection: { _id: 1 } });
		if (!parent) return { ok: false, reason: 'parent_missing' };
	}

	const level: Level = {
		...(parentId ? { parentId } : {}),
		order: input.order,
		slug: input.slug,
		title: input.title,
		description: input.description,
		type: input.type,
		statement: input.statement,
		starterCode: input.starterCode,
		...(input.lockedLines.length > 0 ? { lockedLines: input.lockedLines } : {}),
		...(input.expectedGoal ? { expectedGoal: input.expectedGoal } : {}),
		...(input.targetProof ? { targetProof: input.targetProof } : {}),
		verification: input.verification,
		hints: input.hints,
		published: input.published,
		createdAt: now,
		updatedAt: now
	};

	try {
		await levels.insertOne(level);
	} catch (error) {
		// the unique slug index (levels_slug_unique) rejects a second level with the same slug
		if (error instanceof MongoServerError && error.code === duplicateKeyErrorCode) {
			return { ok: false, reason: 'slug_taken' };
		}
		throw error;
	}
	return { ok: true, slug: input.slug };
}
