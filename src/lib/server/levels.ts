import { ObjectId, type Collection } from 'mongodb';
import type { Level, LevelType } from '$lib/types/level';

// the parts of a level the level page needs, with ids as strings so SvelteKit can serialize them
export interface LevelPageData {
	id: string;
	parentId?: string;
	slug: string;
	order: number;
	title: string;
	description: string;
	type: LevelType;
	statement: string;
	starterCode: string;
	expectedGoal?: string;
	hints: string[];
}

// loads a published level by its URL slug, or `null` if it is missing or unpublished
export async function getPublishedLevelBySlug(
	levels: Pick<Collection<Level>, 'findOne'>,
	slug: string
): Promise<LevelPageData | null> {
	const level = await levels.findOne({ slug, published: true });
	if (!level?._id) return null;

	return {
		id: level._id.toHexString(),
		parentId: level.parentId?.toHexString(),
		slug: level.slug,
		order: level.order,
		title: level.title,
		description: level.description,
		type: level.type,
		statement: level.statement,
		starterCode: level.starterCode,
		expectedGoal: level.expectedGoal,
		hints: level.hints ?? []
	};
}

/**
 * picks the level to offer after `level` is completed, following the level tree:
 * its first child (the level it unlocks), otherwise its next sibling, otherwise none
 * only published levels count. Returns the next level's slug, or null
 */
export async function getNextLevelSlug(
	levels: Pick<Collection<Level>, 'findOne'>,
	level: Pick<LevelPageData, 'id' | 'parentId' | 'order'>
): Promise<string | null> {
	const options = { sort: { order: 1 }, projection: { _id: 0, slug: 1 } } as const;

	const child = await levels.findOne(
		{ parentId: new ObjectId(level.id), published: true },
		options
	);
	if (child) return child.slug;

	const sibling = await levels.findOne(
		{
			parentId: level.parentId ? new ObjectId(level.parentId) : { $exists: false },
			order: { $gt: level.order },
			published: true
		},
		options
	);
	return sibling?.slug ?? null;
}
