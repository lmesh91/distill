import type { ObjectId } from 'mongodb';
import type { LeanDiagnostic, VerificationResult } from './submission';

/** One graded proof check, kept so users can revisit earlier submissions. */
export interface LevelAttempt {
	_id?: ObjectId;
	userId: string;
	levelId: ObjectId;
	source: string;
	accepted: boolean;
	reason: VerificationResult['reason'];
	diagnostics: LeanDiagnostic[];
	/** Comparator explanation for a `verification_failed` rejection. */
	message?: string;
	submittedAt: Date;
}
