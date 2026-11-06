import { error, redirect } from '@sveltejs/kit';
import { ObjectId } from 'mongodb';
import { getLevels, getUserLevelProgresses } from '$lib/server/collections';
import { getNextLevelSlug, getPublishedLevelBySlug, type LevelPageData } from '$lib/server/levels';
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

	// where "Next level" goes after completing this one. Not worth failing the page over
	let nextLevelSlug: string | null = null;
	try {
		nextLevelSlug = await getNextLevelSlug(getLevels(), level);
	} catch (err) {
		console.error('Finding the next level failed:', err);
	}

	return {
		level,
		initialCode: getInitialCode(level, progress),
		// when the code was last saved, for the save indicator
		lastSavedAt: progress?.clientSavedAt?.getTime() ?? null,
		// the server's clock, so autosave timestamps match it even if the device clock is off
		serverNow: Date.now(),
		completed: progress?.status === 'completed',
		nextLevelSlug
	};
};
