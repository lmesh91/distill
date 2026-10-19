import { error, redirect } from '@sveltejs/kit';
import { getLevels } from '$lib/server/collections';
import { getPublishedLevelBySlug, type LevelPageData } from '$lib/server/levels';
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

	return { level, initialCode: getInitialCode(level) };
};
