import { error, redirect } from '@sveltejs/kit';
import { ObjectId } from 'mongodb';
import { getLevels, getUserLevelProgresses } from '$lib/server/collections';
import { getPublishedLevelBySlug, type LevelPageData } from '$lib/server/levels';
import { getLevelProgress, type LevelProgressSnapshot } from '$lib/server/progress';
import { getInitialCode } from '$lib/levels/initialCode';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, url, params }) => {
	const { userId } = locals.auth();
	if (!userId) {
		redirect(307, `/sign-in?redirect_url=${encodeURIComponent(url.href)}`);
	}

	let level: LevelPageData | null;
	try {
		level = await getPublishedLevelBySlug(getLevels(), params.slug);
	} catch (err) {
		console.error('Loading level failed:', err);
		error(503, 'Could not load level');
	}
	if (!level) {
		error(404, 'Level not found');
	}

	let progress: LevelProgressSnapshot | null;
	try {
		progress = await getLevelProgress(getUserLevelProgresses(), userId, new ObjectId(level.id));
	} catch (err) {
		console.error('Loading level progress failed:', err);
		error(503, 'Could not load your progress');
	}

	return { level, initialCode: getInitialCode(level, progress) };
};
