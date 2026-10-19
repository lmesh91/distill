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

/**
 * Saves the user's in-progress code for one level.
 *
 * The write only applies if `clientSavedAt` is newer than the stored one, so a delayed
 * older request can't overwrite newer code. A `completed` status is never downgraded,
 * and submission fields (attempts, errors, completion) are left untouched.
 */
export async function saveLevelProgress(
	levels: Pick<Collection<Level>, 'findOne'>,
	progress: Pick<Collection<UserLevelProgress>, 'updateOne'>,
	{ userId, levelId, code, clientSavedAt }: SaveLevelProgressInput
): Promise<SaveLevelProgressResult> {
	const level = await levels.findOne({ _id: levelId, published: true }, { projection: { _id: 1 } });
	if (!level) return 'level_not_found';

	const now = new Date();
	try {
		await progress.updateOne(
			{
				userId,
				levelId,
				$or: [{ clientSavedAt: { $lt: clientSavedAt } }, { clientSavedAt: { $exists: false } }]
			},
			[
				{
					$set: {
						// $literal: user code may start with `$`, which a pipeline would read as a field path.
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
	} catch (error) {
		// The record exists but has a newer save, so the upsert tried to insert a duplicate.
		if (error instanceof MongoServerError && error.code === duplicateKeyErrorCode) {
			return 'stale';
		}
		throw error;
	}
	return 'saved';
}
