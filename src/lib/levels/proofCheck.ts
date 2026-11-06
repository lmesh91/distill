import type { LeanDiagnostic, VerificationResult } from '$lib/types/submission';

/**
 * the state of a "Check proof" request (#57). the server has no queue: when every Lean worker is
 * busy it answers 503 with Retry-After, so "waiting" means we're retrying until a worker is free,
 * and "running" means a worker has the request and is checking the proof
 */
export type ProofCheckState =
	| { kind: 'idle' }
	| { kind: 'waiting'; since: number }
	| { kind: 'running'; since: number }
	| { kind: 'accepted'; result: VerificationResult }
	| { kind: 'rejected'; result: VerificationResult }
	| { kind: 'error'; message: string };

export class ProofCheckError extends Error {
	/** true when every Lean worker was busy, so trying again soon should work */
	readonly busy: boolean;
	readonly retryAfterMs: number;

	constructor(message: string, { busy = false, retryAfterMs = 0 } = {}) {
		super(message);
		this.busy = busy;
		this.retryAfterMs = retryAfterMs;
	}
}

// how long to keep retrying while Lean is busy before giving up
const defaultMaxWaitMs = 60_000;
// matches the server's limit in src/lib/server/leanLimits.ts, shown so users know what to expect
export const checkTimeLimitSeconds = 30;

/** sends the proof to POST /api/submissions and returns Lean's verdict */
export async function submitProof(
	levelSlug: string,
	source: string,
	{ signal }: { signal?: AbortSignal } = {},
	fetchImpl: typeof fetch = fetch
): Promise<VerificationResult> {
	let response: Response;
	try {
		response = await fetchImpl('/api/submissions', {
			method: 'POST',
			headers: { 'content-type': 'application/json' },
			body: JSON.stringify({ levelSlug, source }),
			signal
		});
	} catch (error) {
		if (signal?.aborted) throw error;
		throw new ProofCheckError('Could not reach the server. Check your connection and try again.');
	}

	if (response.ok) return (await response.json()) as VerificationResult;

	if (response.status === 503 && response.headers.has('retry-after')) {
		const seconds = Number(response.headers.get('retry-after'));
		throw new ProofCheckError('Lean is busy.', {
			busy: true,
			retryAfterMs: Number.isFinite(seconds) ? Math.min(Math.max(seconds, 1), 10) * 1000 : 1000
		});
	}
	if (response.status === 401) throw new ProofCheckError('Sign in again to check your proof.');
	if (response.status === 404) throw new ProofCheckError('This level could not be found.');
	if (response.status === 413) throw new ProofCheckError('Your proof is too long to check.');
	if (response.status === 503) {
		throw new ProofCheckError('Proof checking is unavailable right now. Try again in a minute.');
	}
	throw new ProofCheckError('Could not check your proof. Try again.');
}

export interface ProofCheckerOptions {
	onstate: (state: ProofCheckState) => void;
	submit?: typeof submitProof;
	maxWaitMs?: number;
	now?: () => number;
}

export type ProofChecker = ReturnType<typeof createProofChecker>;

/**
 * runs proof checks one at a time. starting a new check cancels the one in progress, so a slow
 * old result never replaces the newest one
 */
export function createProofChecker({
	onstate,
	submit = submitProof,
	maxWaitMs = defaultMaxWaitMs,
	now = Date.now
}: ProofCheckerOptions) {
	let controller: AbortController | undefined;

	function wait(ms: number, signal: AbortSignal) {
		return new Promise<void>((resolve) => {
			const timer = setTimeout(resolve, ms);
			signal.addEventListener(
				'abort',
				() => {
					clearTimeout(timer);
					resolve();
				},
				{ once: true }
			);
		});
	}

	return {
		/** checks the proof and resolves with the final state (or idle if it was cancelled) */
		async check(levelSlug: string, source: string): Promise<ProofCheckState> {
			controller?.abort();
			const current = new AbortController();
			controller = current;
			const { signal } = current;
			const emit = (state: ProofCheckState) => {
				if (!signal.aborted) onstate(state);
				return state;
			};

			const startedAt = now();
			let waitingSince: number | undefined;
			emit({ kind: 'running', since: startedAt });
			try {
				for (;;) {
					try {
						const result = await submit(levelSlug, source, { signal });
						if (signal.aborted) return { kind: 'idle' };
						return emit({ kind: result.accepted ? 'accepted' : 'rejected', result });
					} catch (error) {
						if (signal.aborted) return { kind: 'idle' };
						if (!(error instanceof ProofCheckError && error.busy)) throw error;
						waitingSince ??= now();
						if (now() - startedAt + error.retryAfterMs > maxWaitMs) {
							throw new ProofCheckError(
								'Lean is still busy checking other proofs. Try again in a minute.'
							);
						}
						emit({ kind: 'waiting', since: waitingSince });
						await wait(error.retryAfterMs, signal);
						if (signal.aborted) return { kind: 'idle' };
						// a worker may be free now; the timer for this attempt starts over
						emit({ kind: 'running', since: now() });
					}
				}
			} catch (error) {
				const message =
					error instanceof ProofCheckError
						? error.message
						: 'Could not check your proof. Try again.';
				return emit({ kind: 'error', message });
			} finally {
				if (controller === current) controller = undefined;
			}
		},

		/** stops waiting for the current check; its result is ignored */
		cancel() {
			controller?.abort();
			controller = undefined;
			onstate({ kind: 'idle' });
		},

		/** true while waiting for a worker or checking */
		get checking() {
			return controller !== undefined;
		}
	};
}

export type ProofCheckTone = 'busy' | 'success' | 'error';

export interface ProofCheckView {
	tone: ProofCheckTone;
	title: string;
	detail: string;
	/** seconds since this step started, while waiting or running */
	elapsed?: number;
}

const count = (n: number, word: string) => `${n} ${word}${n === 1 ? '' : 's'}`;

function problems(diagnostics: LeanDiagnostic[]) {
	const errors = diagnostics.filter((d) => d.severity === 'error');
	const warnings = diagnostics.filter((d) => d.severity === 'warning');
	return { errors, warnings, sorry: warnings.some((d) => d.message.includes('sorry')) };
}

/** what the status shows for a state; null when there's nothing to show */
export function describeProofCheck(state: ProofCheckState, now: number): ProofCheckView | null {
	switch (state.kind) {
		case 'idle':
			return null;
		case 'waiting':
			return {
				tone: 'busy',
				title: 'Waiting for Lean…',
				detail: 'Lean is busy with other proofs. Yours will start as soon as it’s free.',
				elapsed: Math.max(0, Math.floor((now - state.since) / 1000))
			};
		case 'running':
			return {
				tone: 'busy',
				title: 'Checking your proof…',
				detail: `This can take up to ${checkTimeLimitSeconds} seconds.`,
				elapsed: Math.max(0, Math.floor((now - state.since) / 1000))
			};
		case 'accepted':
			return { tone: 'success', title: 'Proof accepted!', detail: 'Lean checked every step.' };
		case 'error':
			return { tone: 'error', title: 'Couldn’t check your proof', detail: state.message };
		case 'rejected': {
			const { result } = state;
			switch (result.reason) {
				case 'diagnostics': {
					const { errors, warnings, sorry } = problems(result.diagnostics);
					if (errors.length > 0) {
						return {
							tone: 'error',
							title: `Not yet: Lean found ${count(errors.length, 'error')}`,
							detail: 'Fix the problems in the Lean output, then check again.'
						};
					}
					return {
						tone: 'error',
						title: sorry
							? 'Not yet: your proof still uses sorry'
							: `Not yet: Lean found ${count(warnings.length, 'warning')}`,
						detail: sorry
							? 'Replace every sorry with a real proof step.'
							: 'Accepted proofs can’t have warnings. Check the Lean output.'
					};
				}
				case 'missing_theorem':
					return {
						tone: 'error',
						title: 'Not yet: the theorem is missing',
						detail: 'Keep the theorem from the starter code, with the same name and statement.'
					};
				case 'introduced_axioms':
					return {
						tone: 'error',
						title: 'Not yet: your proof adds an axiom',
						detail: 'Prove the goal without declaring new axioms.'
					};
				case 'verification_failed':
					return {
						tone: 'error',
						title: 'Not yet: this doesn’t prove the goal',
						detail: 'Make sure the theorem statement is exactly the one you started with.'
					};
				default:
					// a reason the server added later; the Lean output still explains it
					return {
						tone: 'error',
						title: 'Not yet: Lean didn’t accept this proof',
						detail: 'Check the Lean output, then try again.'
					};
			}
		}
	}
}
