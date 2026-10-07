import { getLevels } from './collections';

let ensured: Promise<void> | undefined;

export function ensureIndexes() {
	ensured ??= doEnsureIndexes();
	return ensured;
}

async function doEnsureIndexes() {
	const levels = getLevels();

	await Promise.all([
		levels.createIndex({ slug: 1 }, { unique: true, name: 'levels_slug_unique' }),
		levels.createIndex(
			{ parentId: 1, order: 1 },
			{ name: 'levels_parent_order' }
		),
		levels.createIndex(
			{ published: 1, parentId: 1, order: 1 },
			{ name: 'levels_published_parent_order' }
		)
	]);
}