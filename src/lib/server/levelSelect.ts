import type { Collection, ObjectId } from 'mongodb';
import type { Level, LevelType } from '$lib/types/level';
import type { ProgressStatus, UserLevelProgress } from '$lib/types/progress';

/** one row of the level-select page, with no database ids so SvelteKit can serialize it */
export interface LevelSelectEntry {
	/** 1-based position in play order, shown as the level number */
	number: number;
	slug: string;
	title: string;
	type: LevelType;
	status: ProgressStatus;
}

type LevelNode = Pick<Level, 'parentId' | 'order' | 'slug'> & { _id: ObjectId };

const levelFields = { _id: 1, parentId: 1, order: 1, slug: 1, title: 1, type: 1 } as const;

/**
 * puts levels in play order by walking the level tree: each level, then its children,
 * then its next sibling (siblings by `order`), the same tree rule post-completion
 * navigation (#59) uses to pick the next level
 *
 * a level whose parent isn't in the list (unpublished or deleted) is treated as a root, so
 * a published level never disappears from the page. the tree-based map comes later (#128)
 */
export function inPlayOrder<T extends LevelNode>(levels: T[]): T[] {
	const ids = new Set(levels.map((level) => level._id.toHexString()));
	const children = new Map<string, T[]>();
	for (const level of levels) {
		const parent = level.parentId?.toHexString();
		const key = parent && ids.has(parent) ? parent : '';
		children.set(key, [...(children.get(key) ?? []), level]);
	}
	for (const siblings of children.values()) {
		// slug breaks ties so the order is stable when two siblings share an order
		siblings.sort((a, b) => a.order - b.order || a.slug.localeCompare(b.slug));
	}

	const ordered: T[] = [];
	const visited = new Set<string>();
	const visit = (key: string) => {
		for (const level of children.get(key) ?? []) {
			const id = level._id.toHexString();
			// a parent cycle in bad data would otherwise loop forever
			if (visited.has(id)) continue;
			visited.add(id);
			ordered.push(level);
			visit(id);
		}
	};
	visit('');
	return ordered;
}

/**
 * loads every published level in play order with the user's status on each:
 * `completed` once a proof was accepted (#75), `in_progress` once they saved code
 */
export async function getLevelSelect(
	levels: Pick<Collection<Level>, 'find'>,
	progress: Pick<Collection<UserLevelProgress>, 'find'>,
	userId: string
): Promise<LevelSelectEntry[]> {
	const [published, records] = await Promise.all([
		levels.find({ published: true }, { projection: levelFields }).toArray() as Promise<
			(LevelNode & Pick<Level, 'title' | 'type'>)[]
		>,
		progress
			.find({ userId }, { projection: { _id: 0, levelId: 1, status: 1 } })
			.toArray() as Promise<Pick<UserLevelProgress, 'levelId' | 'status'>[]>
	]);

	const statuses = new Map(records.map((record) => [record.levelId.toHexString(), record.status]));
	return inPlayOrder(published).map((level, index) => ({
		number: index + 1,
		slug: level.slug,
		title: level.title,
		type: level.type,
		status: statuses.get(level._id.toHexString()) ?? 'not_started'
	}));
}

/** the level the "continue" button opens: the first one in play order that isn't completed */
export function nextUnfinished(entries: LevelSelectEntry[]): LevelSelectEntry | undefined {
	return entries.find((entry) => entry.status !== 'completed');
}
