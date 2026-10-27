import { runLeanJob } from './leanJobs.ts';
import type { VerificationTarget } from '../types/submission.ts';

export function isVerificationTarget(value: unknown): value is VerificationTarget {
	if (!value || typeof value !== 'object') return false;
	const target = value as Partial<VerificationTarget>;
	return (
		typeof target.theoremName === 'string' &&
		!!target.theoremName.trim() &&
		typeof target.challengeSource === 'string' &&
		!!target.challengeSource.trim()
	);
}

export function verifyLean(source: string, target: VerificationTarget, signal?: AbortSignal) {
	if (!isVerificationTarget(target))
		return Promise.reject(new Error('Level has no verification target'));
	return runLeanJob({ kind: 'verify', source, target }, { signal });
}
