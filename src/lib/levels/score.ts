/**
 * the score shown when a level is completed (#118), following the scoring spec (#113):
 * attempts and time are fixed at the first solve. proof length (Lean tokens in the shortest
 * accepted proof) needs a token counter on the Lean side, so it isn't shown yet
 */
export interface LevelScore {
	/** proof checks up to and including the first accepted one; null for older records */
	attempts: number | null;
	/** seconds from first opening the level to the first solve; null when unknown */
	seconds: number | null;
}

/** the progress fields the score comes from, as the submission API returns them */
export interface ScoreProgress {
	solveAttemptCount?: number;
	startedAt?: string | Date;
	completedAt?: string | Date;
}

export function levelScore(progress: ScoreProgress | undefined): LevelScore {
	const started = progress?.startedAt ? new Date(progress.startedAt).getTime() : NaN;
	const completed = progress?.completedAt ? new Date(progress.completedAt).getTime() : NaN;
	const seconds =
		Number.isFinite(started) && Number.isFinite(completed) && completed >= started
			? Math.round((completed - started) / 1000)
			: null;
	const attempts = progress?.solveAttemptCount;
	return {
		attempts: typeof attempts === 'number' && attempts >= 1 ? attempts : null,
		seconds
	};
}

/** a short duration like "45s", "3m 05s" or "1h 02m" */
export function formatDuration(seconds: number): string {
	const total = Math.max(0, Math.round(seconds));
	const h = Math.floor(total / 3600);
	const m = Math.floor((total % 3600) / 60);
	const s = total % 60;
	const pad = (n: number) => String(n).padStart(2, '0');
	if (h > 0) return `${h}h ${pad(m)}m`;
	if (m > 0) return `${m}m ${pad(s)}s`;
	return `${s}s`;
}
