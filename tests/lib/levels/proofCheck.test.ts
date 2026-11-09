import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
	ProofCheckError,
	createProofChecker,
	describeProofCheck,
	submitProof,
	type ProofCheckState
} from '../../../src/lib/levels/proofCheck.ts';
import type { VerificationResult } from '../../../src/lib/types/submission.ts';

const accepted: VerificationResult = {
	accepted: true,
	compiled: true,
	reason: 'accepted',
	diagnostics: [],
	verification: { theoremName: 'demo', dependencies: [], axioms: [], introducedAxioms: [] }
};

function rejected(overrides: Partial<VerificationResult>): VerificationResult {
	return { ...accepted, accepted: false, reason: 'diagnostics', ...overrides };
}

const settle = () => new Promise((resolve) => setImmediate(resolve));

function fakeFetch(status: number, body: unknown = {}, headers: Record<string, string> = {}) {
	return (async () =>
		new Response(JSON.stringify(body), { status, headers })) as unknown as typeof fetch;
}

test('submitProof posts the level and code and returns the verdict', async () => {
	let sent: { url: string; body: unknown } | undefined;
	const fetchImpl = (async (url: string, init: RequestInit) => {
		sent = { url, body: JSON.parse(String(init.body)) };
		return new Response(JSON.stringify(accepted), { status: 200 });
	}) as unknown as typeof fetch;

	assert.deepEqual(await submitProof('hello', 'rfl', {}, fetchImpl), accepted);
	assert.deepEqual(sent, { url: '/api/submissions', body: { levelSlug: 'hello', source: 'rfl' } });
});

test('submitProof tells a busy server apart from other failures', async () => {
	await assert.rejects(
		submitProof('hello', 'rfl', {}, fakeFetch(503, {}, { 'retry-after': '2' })),
		(error: unknown) =>
			error instanceof ProofCheckError && error.busy && error.retryAfterMs === 2000
	);
	for (const [status, message] of [
		[401, 'Sign in again to check your proof.'],
		[404, 'This level could not be found.'],
		[413, 'Your proof is too long to check.'],
		[503, 'Proof checking is unavailable right now. Try again in a minute.'],
		[500, 'Could not check your proof. Try again.']
	] as const) {
		await assert.rejects(
			submitProof('hello', 'rfl', {}, fakeFetch(status)),
			(error: unknown) =>
				error instanceof ProofCheckError && !error.busy && error.message === message
		);
	}
	const offline = (async () => {
		throw new TypeError('fetch failed');
	}) as unknown as typeof fetch;
	await assert.rejects(submitProof('hello', 'rfl', {}, offline), /Could not reach the server/);
});

test('an unconfigured level explains the missing setup without retrying', async () => {
	await assert.rejects(
		submitProof(
			'w1-3',
			'example : 1 + 1 = 2 := by rfl',
			{},
			fakeFetch(503, { error: 'Level verification is not configured' })
		),
		(error: unknown) =>
			error instanceof ProofCheckError &&
			!error.busy &&
			error.message ===
				'Proof checking has not been set up for this level yet. The level author needs to finish its setup.'
	);
});

test('a malformed service error still shows the fallback message', async () => {
	const fetchImpl = (async () =>
		new Response('Service unavailable', { status: 503 })) as typeof fetch;
	await assert.rejects(
		submitProof('w1-3', 'rfl', {}, fetchImpl),
		/Proof checking is unavailable right now/
	);
});

test('a check shows running, then the verdict', async () => {
	const states: ProofCheckState[] = [];
	const checker = createProofChecker({
		onstate: (state) => states.push(state),
		submit: async () => rejected({ diagnostics: [] }),
		now: () => 1000
	});

	const final = await checker.check('hello', 'rfl');
	assert.deepEqual(
		states.map((s) => s.kind),
		['running', 'rejected']
	);
	assert.equal(final.kind, 'rejected');
	assert.equal(checker.checking, false);
});

test('while Lean is busy the check waits and retries, then runs', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	let clock = 0;
	let busyAnswers = 2;
	const states: ProofCheckState[] = [];
	const checker = createProofChecker({
		onstate: (state) => states.push(state),
		now: () => clock,
		submit: async () => {
			if (busyAnswers-- > 0)
				throw new ProofCheckError('Lean is busy.', { busy: true, retryAfterMs: 1000 });
			return accepted;
		}
	});

	const done = checker.check('hello', 'rfl');
	await settle();
	assert.deepEqual(states.at(-1), { kind: 'waiting', since: 0 });
	assert.equal(checker.checking, true);

	clock = 1000;
	t.mock.timers.tick(1000);
	await settle();
	clock = 2000;
	t.mock.timers.tick(1000);
	assert.equal((await done).kind, 'accepted');
	assert.deepEqual(
		states.map((s) => s.kind),
		['running', 'waiting', 'running', 'waiting', 'running', 'accepted']
	);
	// the waiting timer keeps counting from the first busy answer
	assert.deepEqual(states[3], { kind: 'waiting', since: 0 });
});

test('it gives up waiting after a minute instead of spinning forever', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	let clock = 0;
	const checker = createProofChecker({
		onstate: () => {},
		now: () => clock,
		maxWaitMs: 3000,
		submit: async () => {
			throw new ProofCheckError('Lean is busy.', { busy: true, retryAfterMs: 1000 });
		}
	});

	const done = checker.check('hello', 'rfl');
	for (let i = 0; i < 3; i++) {
		await settle();
		clock += 1000;
		t.mock.timers.tick(1000);
	}
	const final = await done;
	assert.equal(final.kind, 'error');
	assert.match((final as { message: string }).message, /still busy/);
});

test('starting a new check cancels the old one, so its result is ignored', async () => {
	const states: ProofCheckState[] = [];
	const finishers: Array<() => void> = [];
	const checker = createProofChecker({
		onstate: (state) => states.push(state),
		now: () => 0,
		submit: (_slug, source, { signal } = {}) =>
			new Promise((resolve, reject) => {
				finishers.push(() => resolve(source === 'new' ? accepted : rejected({})));
				signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')));
			})
	});

	const first = checker.check('hello', 'old');
	const second = checker.check('hello', 'new');
	finishers[1]();
	assert.equal((await second).kind, 'accepted');
	assert.equal((await first).kind, 'idle');
	assert.deepEqual(
		states.map((s) => s.kind),
		['running', 'running', 'accepted']
	);
});

test('cancel stops the check and goes back to idle', async () => {
	const states: ProofCheckState[] = [];
	const checker = createProofChecker({
		onstate: (state) => states.push(state),
		submit: (_slug, _source, { signal } = {}) =>
			new Promise((_resolve, reject) =>
				signal?.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')))
			)
	});
	const done = checker.check('hello', 'rfl');
	checker.cancel();
	assert.equal((await done).kind, 'idle');
	assert.deepEqual(states.at(-1), { kind: 'idle' });
	assert.equal(checker.checking, false);
});

test('cancel while waiting prevents further retries', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	const states: ProofCheckState[] = [];
	let submissions = 0;
	const checker = createProofChecker({
		onstate: (state) => states.push(state),
		submit: async () => {
			submissions++;
			throw new ProofCheckError('Lean is busy.', { busy: true, retryAfterMs: 1000 });
		}
	});

	const done = checker.check('hello', 'rfl');
	await settle();
	assert.equal(states.at(-1)?.kind, 'waiting');
	checker.cancel();
	t.mock.timers.tick(10_000);
	assert.equal((await done).kind, 'idle');
	assert.equal(submissions, 1);
	assert.equal(checker.checking, false);
	assert.deepEqual(states.at(-1), { kind: 'idle' });
});

test('a cancelled result cannot appear after editing code or leaving the level', async () => {
	const states: ProofCheckState[] = [];
	let finish!: (result: VerificationResult) => void;
	const checker = createProofChecker({
		onstate: (state) => states.push(state),
		// Simulate a response that finishes despite the cancellation.
		submit: () => new Promise((resolve) => (finish = resolve))
	});

	const done = checker.check('hello', 'rfl');
	checker.cancel();
	finish(accepted);
	assert.equal((await done).kind, 'idle');
	assert.deepEqual(
		states.map((state) => state.kind),
		['running', 'idle']
	);
});

test('describeProofCheck shows elapsed time while busy and explains rejections', () => {
	assert.equal(describeProofCheck({ kind: 'idle' }, 0), null);
	assert.deepEqual(describeProofCheck({ kind: 'running', since: 1000 }, 5900), {
		tone: 'busy',
		title: 'Checking your proof…',
		detail: 'This can take up to 30 seconds.',
		elapsed: 4
	});
	assert.equal(describeProofCheck({ kind: 'waiting', since: 0 }, 2000)?.title, 'Waiting for Lean…');
	assert.equal(describeProofCheck({ kind: 'accepted', result: accepted }, 0)?.tone, 'success');

	const error = (message: string) => ({ severity: 'error' as const, message });
	const titleFor = (result: VerificationResult) =>
		describeProofCheck({ kind: 'rejected', result }, 0)?.title;
	assert.equal(
		titleFor(rejected({ diagnostics: [error('a'), error('b')] })),
		'Not yet: Lean found 2 errors'
	);
	assert.equal(
		titleFor(
			rejected({ diagnostics: [{ severity: 'warning', message: "declaration uses 'sorry'" }] })
		),
		'Not yet: your proof still uses sorry'
	);
	assert.equal(
		titleFor(rejected({ reason: 'missing_theorem' })),
		'Not yet: the theorem is missing'
	);
	assert.equal(
		titleFor(rejected({ reason: 'introduced_axioms' })),
		'Not yet: your proof adds an axiom'
	);
	assert.equal(
		titleFor(rejected({ reason: 'verification_failed' })),
		'Not yet: this doesn’t prove the goal'
	);
	assert.equal(
		describeProofCheck({ kind: 'error', message: 'Sign in again to check your proof.' }, 0)?.detail,
		'Sign in again to check your proof.'
	);
});
