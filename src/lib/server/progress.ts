import { MongoServerError, type Collection, type ObjectId } from 'mongodb';
import type { Level } from '$lib/types/level';
import type { UserLevelProgress } from '$lib/types/progress';

export type SaveLevelProgressResult = 'saved' | 'stale' | 'level_not_found';

export interface SaveLevelProgressInput {
	userId: string;
	levelId: ObjectId;
	code: string;
	clientSavedAt: Date;
}

const duplicateKeyErrorCode = 11000;

export type LevelProgressSnapshot = Pick<
	UserLevelProgress,
	'status' | 'currentCode' | 'clientSavedAt'
>;

/**
 * loads the parts of the user's saved progress the level page needs, or `null` if none exists
 */
export async function getLevelProgress(
	progress: Pick<Collection<UserLevelProgress>, 'findOne'>,
	userId: string,
	levelId: ObjectId
): Promise<LevelProgressSnapshot | null> {
	return progress.findOne<LevelProgressSnapshot>(
		{ userId, levelId },
		{ projection: { _id: 0, status: 1, currentCode: 1, clientSavedAt: 1 } }
	);
}

/**
 * saves the user's in-progress code for one level
 *
 * the write only applies if `clientSavedAt` is newer than the stored one, so a delayed
 * older request can't overwrite newer code. A `completed` status is never downgraded,
 * and submission fields (attempts, errors, completion) are left untouched
 */
export async function saveLevelProgress(
	levels: Pick<Collection<Level>, 'findOne'>,
	progress: Pick<Collection<UserLevelProgress>, 'updateOne'>,
	{ userId, levelId, code, clientSavedAt }: SaveLevelProgressInput
): Promise<SaveLevelProgressResult> {
	const level = await levels.findOne({ _id: levelId, published: true }, { projection: { _id: 1 } });
	if (!level) return 'level_not_found';

	const now = new Date();
	const save = () =>
		progress.updateOne(
			{
				userId,
				levelId,
				$or: [{ clientSavedAt: { $lt: clientSavedAt } }, { clientSavedAt: { $exists: false } }]
			},
			[
				{
					$set: {
						// $literal: user code may start with `$`, which a pipeline would read as a field path
						currentCode: { $literal: code },
						clientSavedAt: { $literal: clientSavedAt },
						status: {
							$cond: [{ $eq: ['$status', 'completed'] }, 'completed', 'in_progress']
						},
						startedAt: { $ifNull: ['$startedAt', { $literal: now }] },
						attemptCount: { $ifNull: ['$attemptCount', 0] }
					}
				}
			],
			{ upsert: true }
		);
	const isDuplicate = (error: unknown) =>
		error instanceof MongoServerError && error.code === duplicateKeyErrorCode;
	try {
		await save();
	} catch (error) {
		if (!isDuplicate(error)) throw error;
		// a concurrent first write (such as a proof check) may have created the record without
		// a save time, which the retry matches; a second collision means a newer save exists
		try {
			await save();
		} catch (retryError) {
			if (isDuplicate(retryError)) return 'stale';
			throw retryError;
		}
	}
	return 'saved';
}
