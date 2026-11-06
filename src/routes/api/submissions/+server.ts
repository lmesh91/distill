import { createSubmissionHandler } from '../../../lib/server/submissions.ts';

export const POST = createSubmissionHandler(async (slug) => {
	const { getLevels } = await import('../../../lib/server/collections');
	return getLevels().findOne({ slug, published: true }, { projection: { verification: 1 } });
});
