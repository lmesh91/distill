import {
	MongoServerError,
	type ClientSession,
	type Collection,
	type MongoClient,
	type ObjectId
} from 'mongodb';
import type { LevelAttempt } from '../types/attempt.ts';
import type { UserLevelProgress } from '../types/progress.ts';
import type { VerificationResult } from '../types/submission.ts';

export interface RecordAttemptInput {
	userId: string;
	levelId: ObjectId;
	source: string;
	result: VerificationResult;
}

export type AttemptProgress = Pick<UserLevelProgress, 'status' | 'attemptCount' | 'completedAt'>;

const duplicateKeyErrorCode = 11000;

/** The first error explains a rejection better than the reason code alone. */
export function attemptErrorMessage(result: VerificationResult): string {
	const diagnostic =
		result.diagnostics.find((d) => d.severity === 'error') ??
		result.diagnostics.find((d) => d.severity === 'warning');
	return diagnostic?.message ?? result.verification?.message ?? result.reason;
}

/**
 * stores the attempt in the user's history and updates their progress for the level,
 * in one transaction so the history and `attemptCount` cannot disagree
 *
 * only an accepted result marks the level completed; a rejection never downgrades a
 * level that was already completed, and the first completion time is kept
 */
export async function recordAttempt(
	client: Pick<MongoClient, 'withSession'>,
	attempts: Pick<Collection<LevelAttempt>, 'insertOne'>,
	progress: Pick<Collection<UserLevelProgress>, 'findOneAndUpdate'>,
	{ userId, levelId, source, result }: RecordAttemptInput
): Promise<AttemptProgress> {
	const now = new Date();
	const set: Record<string, unknown> = {
		// $literal: user code may start with `$`, which a pipeline would read as a field path
		currentCode: { $literal: source },
		attemptCount: { $add: [{ $ifNull: ['$attemptCount', 0] }, 1] },
		lastAttemptedAt: { $literal: now },
		startedAt: { $ifNull: ['$startedAt', { $literal: now }] }
	};
	if (result.accepted) {
		set.status = 'completed';
		set.completedAt = { $ifNull: ['$completedAt', { $literal: now }] };
		set.currentError = '$$REMOVE';
	} else {
		set.status = { $cond: [{ $eq: ['$status', 'completed'] }, 'completed', 'in_progress'] };
		set.currentError = { $literal: attemptErrorMessage(result) };
	}

	const write = async (session: ClientSession) => {
		await attempts.insertOne(
			{
				userId,
				levelId,
				source,
				accepted: result.accepted,
				reason: result.reason,
				diagnostics: result.diagnostics,
				message: result.verification?.message,
				submittedAt: now
			},
			{ session }
		);
		const updated = await progress.findOneAndUpdate({ userId, levelId }, [{ $set: set }], {
			upsert: true,
			returnDocument: 'after',
			projection: { _id: 0, status: 1, attemptCount: 1, completedAt: 1 },
			session
		});
		if (!updated) throw new Error('Progress update returned no document');
		return updated as AttemptProgress;
	};
	const transaction = () =>
		client.withSession((session) => session.withTransaction(() => write(session)));

	try {
		return await transaction();
	} catch (error) {
		// a concurrent first write inserted the progress record; retrying now updates it
		if (!(error instanceof MongoServerError && error.code === duplicateKeyErrorCode)) throw error;
		return transaction();
	}
}
