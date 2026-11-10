import type { Collection } from 'mongodb';
import type { Level, LevelType } from '$lib/types/level';

/** the parts of a level the level page needs, with ids as strings so SvelteKit can serialize them */
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
	lockedLines: number[];
	expectedGoal?: string;
	targetProof?: string;
	hints: string[];
}

/**
 * Loads a published level by its URL slug, or `null` if it is missing or unpublished.
 */
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
		lockedLines: level.lockedLines ?? [],
		expectedGoal: level.expectedGoal,
		targetProof: level.targetProof,
		hints: level.hints ?? []
	};
}
