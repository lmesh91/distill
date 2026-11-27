import { error } from '@sveltejs/kit';
import { getLevels, getUserLevelProgresses, getUsers } from '$lib/server/collections';
import { getProfileStats, type ProfileStats } from '$lib/server/profileStats';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals }) => {
	const { userId } = locals.auth();
	if (!userId) {
		error(401, 'Unauthorized');
	}

	let stats: ProfileStats;
	let user: { displayName?: string; createdAt?: Date } | null;
	try {
		[stats, user] = await Promise.all([
			getProfileStats(getLevels(), getUserLevelProgresses(), userId),
			// only public details: the email address stays off the profile
			getUsers().findOne({ _id: userId }, { projection: { _id: 0, displayName: 1, createdAt: 1 } })
		]);
	} catch (err) {
		console.error('Loading the profile failed:', err);
		error(503, 'Could not load your profile');
	}

	return {
		stats,
		displayName: user?.displayName ?? null,
		memberSince: user?.createdAt?.toISOString() ?? null
	};
};
