import { createSubmissionHandler } from '../../../lib/server/submissions.ts';

export const POST = createSubmissionHandler(
	async (slug) => {
		const { getLevels } = await import('../../../lib/server/collections');
		return getLevels().findOne(
			{ slug, published: true },
			{ projection: { _id: 1, verification: 1 } }
		);
	},
	async (input) => {
		const [{ getAttempts, getUserLevelProgresses }, { getMongoClient }, { recordAttempt }] =
			await Promise.all([
				import('../../../lib/server/collections'),
				import('../../../lib/server/db'),
				import('../../../lib/server/attempts.ts')
			]);
		return recordAttempt(getMongoClient(), getAttempts(), getUserLevelProgresses(), input);
	}
);
