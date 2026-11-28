import { error, fail, redirect } from '@sveltejs/kit';
import { parseLevelForm, type NewLevelInput } from '$lib/admin/levelForm';
import { getLevels } from '$lib/server/collections';
import { createLevel } from '$lib/server/levelCreation';
import { requireAdmin } from '$lib/server/roles';
import type { Actions, PageServerLoad } from './$types';

// hooks.server.ts already limits /admin to administrators; the checks here keep that true if
// the route is ever moved

export const load: PageServerLoad = async ({ locals, url }) => {
	requireAdmin(locals);
	let levels;
	try {
		levels = await getLevels()
			.find({}, { projection: { _id: 1, title: 1, slug: 1, order: 1, parentId: 1, published: 1 } })
			.sort({ order: 1, slug: 1 })
			.toArray();
	} catch (err) {
		console.error('Loading levels for the admin form failed:', err);
		error(503, 'Could not load levels');
	}

	// the order a new level gets by default: after its last sibling
	const nextOrder: Record<string, number> = {};
	for (const level of levels) {
		const key = level.parentId?.toHexString() ?? '';
		nextOrder[key] = Math.max(nextOrder[key] ?? 0, level.order + 1);
	}

	return {
		parents: levels.map((level) => ({
			id: level._id.toHexString(),
			label: `${level.title} (${level.slug})${level.published ? '' : ' · draft'}`
		})),
		nextOrder,
		created: url.searchParams.get('created')
	};
};

export const actions: Actions = {
	default: async ({ request, locals }) => {
		requireAdmin(locals);
		const result = parseLevelForm(await request.formData());
		if (!result.ok) return fail(400, { errors: result.errors, values: result.values });

		let saved;
		try {
			saved = await createLevel(getLevels(), result.level);
		} catch (err) {
			console.error('Creating a level failed:', err);
			return fail(503, {
				errors: { title: 'The level could not be saved. Try again in a moment.' },
				values: valuesOf(result.level)
			});
		}
		if (!saved.ok) {
			const values = valuesOf(result.level);
			return saved.reason === 'slug_taken'
				? fail(409, { errors: { slug: 'Another level already uses this slug.' }, values })
				: fail(400, { errors: { parentId: 'That parent level no longer exists.' }, values });
		}
		redirect(303, `/admin/levels/new?created=${encodeURIComponent(saved.slug)}`);
	}
};

/** the form's raw values from a parsed level, to show it again after a save fails */
function valuesOf(level: NewLevelInput) {
	return {
		title: level.title,
		slug: level.slug,
		description: level.description,
		type: level.type,
		statement: level.statement,
		starterCode: level.starterCode,
		lockedLines: level.lockedLines.join(', '),
		expectedGoal: level.expectedGoal ?? '',
		targetProof: level.targetProof ?? '',
		hints: level.hints.join('\n'),
		theoremName: level.verification.theoremName,
		challengeSource: level.verification.challengeSource,
		parentId: level.parentId ?? '',
		order: String(level.order),
		published: level.published
	};
}
