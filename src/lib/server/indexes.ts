import { getLevels, getUserLevelProgresses } from './collections';

let ensured: Promise<void> | undefined;

export function ensureIndexes() {
	ensured ??= doEnsureIndexes();
	return ensured;
}

async function doEnsureIndexes() {
	const levels = getLevels();
	const progress = getUserLevelProgresses();

    // for users: if we make global xp leaderboard,
    // we can add an index on totalXP
	// for progress: if we make per level leaderboard, new index
	await Promise.all([
		levels.createIndex({ slug: 1 }, { unique: true, name: 'levels_slug_unique' }),
		levels.createIndex(
			{ parentId: 1, order: 1 },
			{ name: 'levels_parent_order' }
		),
		levels.createIndex(
			{ published: 1, parentId: 1, order: 1 },
			{ name: 'levels_published_parent_order' }
		),
		progress.createIndex(
			{ userId: 1, levelId: 1 },
			{ unique: true, name: 'progress_user_level_unique' }
		),
	]);
}