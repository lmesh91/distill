import { error } from '@sveltejs/kit';
import { getLevels, getUserLevelProgresses } from '$lib/server/collections';
import { getLevelSelect, nextUnfinished, type LevelSelectEntry } from '$lib/server/levelSelect';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
	const { userId } = locals.auth();
	if (!userId) {
		error(401, 'Unauthorized');
	}

	let levels: LevelSelectEntry[];
	try {
		levels = await getLevelSelect(getLevels(), getUserLevelProgresses(), userId);
	} catch (err) {
		console.error('Loading the level list failed:', err);
		error(503, 'Could not load levels');
	}

	return {
		levels,
		// the "continue" button; none once every level is completed
		continueSlug: nextUnfinished(levels)?.slug ?? null
	};
};
