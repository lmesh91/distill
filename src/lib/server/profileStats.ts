import type { Collection, ObjectId } from 'mongodb';
import type { Level } from '$lib/types/level';
import type { UserLevelProgress } from '$lib/types/progress';

/** one completed level on the profile, oldest solve first */
export interface ProfileSolve {
	slug: string;
	title: string;
	/** checks up to the first solve; null for levels solved before this was recorded (#118) */
	attempts: number | null;
	/** seconds from first opening the level to the first solve; null when unknown */
	seconds: number | null;
	completedAt: string;
}

/** the learning statistics on the profile page (#31), from the user's progress records */
export interface ProfileStats {
	completed: number;
	inProgress: number;
	/** published levels, so the page can show "3 of 6" */
	total: number;
	/** every proof check the user ran, accepted or not */
	checks: number;
	/** average checks per solved level, over levels where that is known */
	averageAttempts: number | null;
	solves: ProfileSolve[];
}

type ProgressRecord = Pick<
	UserLevelProgress,
	'levelId' | 'status' | 'attemptCount' | 'startedAt' | 'completedAt'
> & { solveAttemptCount?: number };

type LevelInfo = Pick<Level, 'slug' | 'title'> & { _id: ObjectId };

/** works out the profile statistics from published levels and the user's progress */
export function summarizeProgress(levels: LevelInfo[], records: ProgressRecord[]): ProfileStats {
	const byId = new Map(levels.map((level) => [level._id.toHexString(), level]));
	// progress on levels that were since unpublished doesn't count toward "x of y"
	const visible = records.filter((record) => byId.has(record.levelId.toHexString()));

	const solves: ProfileSolve[] = [];
	for (const record of visible) {
		if (record.status !== 'completed' || !record.completedAt) continue;
		const level = byId.get(record.levelId.toHexString())!;
		const started = record.startedAt?.getTime();
		const completed = record.completedAt.getTime();
		solves.push({
			slug: level.slug,
			title: level.title,
			attempts:
				typeof record.solveAttemptCount === 'number' && record.solveAttemptCount >= 1
					? record.solveAttemptCount
					: null,
			seconds:
				started !== undefined && completed >= started
					? Math.round((completed - started) / 1000)
					: null,
			completedAt: record.completedAt.toISOString()
		});
	}
	solves.sort((a, b) => a.completedAt.localeCompare(b.completedAt));

	const known = solves.flatMap((solve) => (solve.attempts === null ? [] : [solve.attempts]));
	return {
		completed: solves.length,
		inProgress: visible.filter((record) => record.status === 'in_progress').length,
		total: levels.length,
		checks: visible.reduce((sum, record) => sum + (record.attemptCount ?? 0), 0),
		averageAttempts:
			known.length > 0
				? Math.round((known.reduce((a, b) => a + b, 0) / known.length) * 10) / 10
				: null,
		solves
	};
}

/** loads the statistics for one user; Deven's #35 can replace or extend this */
export async function getProfileStats(
	levels: Pick<Collection<Level>, 'find'>,
	progress: Pick<Collection<UserLevelProgress>, 'find'>,
	userId: string
): Promise<ProfileStats> {
	const [published, records] = await Promise.all([
		levels
			.find({ published: true }, { projection: { _id: 1, slug: 1, title: 1 } })
			.toArray() as Promise<LevelInfo[]>,
		progress
			.find(
				{ userId },
				{
					projection: {
						_id: 0,
						levelId: 1,
						status: 1,
						attemptCount: 1,
						startedAt: 1,
						completedAt: 1,
						solveAttemptCount: 1
					}
				}
			)
			.toArray() as Promise<ProgressRecord[]>
	]);
	return summarizeProgress(published, records);
}
