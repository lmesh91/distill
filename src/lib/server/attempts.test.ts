import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MongoServerError, ObjectId } from 'mongodb';
import { attemptErrorMessage, recordAttempt } from './attempts.ts';
import type { VerificationResult } from '../types/submission.ts';

const levelId = new ObjectId();
const accepted: VerificationResult = {
	accepted: true,
	compiled: true,
	diagnostics: [],
	reason: 'accepted',
	verification: { theoremName: 'target', dependencies: [], axioms: [], introducedAxioms: [] }
};
const rejected: VerificationResult = {
	accepted: false,
	compiled: false,
	diagnostics: [
		{ severity: 'warning', message: 'unused variable' },
		{ severity: 'error', message: 'Type mismatch' }
	],
	reason: 'diagnostics',
	verification: null
};

type Client = Parameters<typeof recordAttempt>[0];
type Attempts = Parameters<typeof recordAttempt>[1];
type Progress = Parameters<typeof recordAttempt>[2];
type UpdateArgs = [filter: unknown, update: unknown, options: unknown];

function fakes({ updateErrors = [] as Error[] } = {}) {
	const session = { id: 'session' };
	let transactions = 0;
	const client = {
		withSession: async (run: (s: unknown) => Promise<unknown>) =>
			run({
				...session,
				withTransaction: async (fn: () => Promise<unknown>) => {
					transactions++;
					return fn();
				}
			})
	} as unknown as Client;
	const inserted: { doc: unknown; options: unknown }[] = [];
	const updates: { filter: UpdateArgs[0]; update: UpdateArgs[1]; options: UpdateArgs[2] }[] = [];
	const attempts = {
		insertOne: async (doc: unknown, options: unknown) => {
			inserted.push({ doc, options });
			return { acknowledged: true, insertedId: new ObjectId() };
		}
	} as unknown as Attempts;
	const progress = {
		findOneAndUpdate: async (...[filter, update, options]: UpdateArgs) => {
			updates.push({ filter, update, options });
			const error = updateErrors.shift();
			if (error) throw error;
			return { status: 'completed', attemptCount: 1 };
		}
	} as unknown as Progress;
	return { client, attempts, progress, inserted, updates, transactions: () => transactions };
}

function sessionOf(options: unknown) {
	return (options as { session?: { id?: string } }).session?.id;
}

function setOf(update: UpdateArgs[1]) {
	return (update as { $set: Record<string, unknown> }[])[0].$set;
}

const input = (result: VerificationResult) => ({
	userId: 'user-1',
	levelId,
	source: '$status',
	result
});

test('every attempt is stored in the history with its verdict and diagnostics', async () => {
	const { client, attempts, progress, inserted } = fakes();
	await recordAttempt(client, attempts, progress, input(rejected));
	assert.equal(inserted.length, 1);
	const doc = inserted[0].doc as Record<string, unknown>;
	assert.ok(doc.submittedAt instanceof Date);
	assert.deepEqual(
		{ ...doc, submittedAt: undefined },
		{
			userId: 'user-1',
			levelId,
			source: '$status',
			accepted: false,
			reason: 'diagnostics',
			diagnostics: rejected.diagnostics,
			message: undefined,
			submittedAt: undefined
		}
	);
});

test('the comparator message is kept on the attempt itself', async () => {
	const { client, attempts, progress, inserted } = fakes();
	await recordAttempt(
		client,
		attempts,
		progress,
		input({
			...accepted,
			accepted: false,
			reason: 'verification_failed',
			verification: { ...accepted.verification!, message: 'axiom not allowed' }
		})
	);
	assert.equal((inserted[0].doc as { message?: string }).message, 'axiom not allowed');
});

test('the history insert and progress update share one transaction', async () => {
	const { client, attempts, progress, inserted, updates, transactions } = fakes();
	await recordAttempt(client, attempts, progress, input(accepted));
	assert.equal(transactions(), 1);
	assert.equal(sessionOf(inserted[0].options), 'session');
	assert.equal(sessionOf(updates[0].options), 'session');
});

test('an accepted attempt completes the level once and clears the error', async () => {
	const { client, attempts, progress, updates } = fakes();
	assert.deepEqual(await recordAttempt(client, attempts, progress, input(accepted)), {
		status: 'completed',
		attemptCount: 1
	});
	const [{ filter, update, options }] = updates;
	assert.deepEqual(filter, { userId: 'user-1', levelId });
	const { session, ...rest } = options as Record<string, unknown>;
	assert.ok(session);
	assert.deepEqual(rest, {
		upsert: true,
		returnDocument: 'after',
		projection: { _id: 0, status: 1, attemptCount: 1, completedAt: 1 }
	});
	const set = setOf(update) as Record<string, { $ifNull?: unknown[] }>;
	assert.equal(set.status, 'completed');
	assert.equal(set.completedAt.$ifNull?.[0], '$completedAt');
	assert.equal(set.currentError, '$$REMOVE');
	assert.deepEqual(set.attemptCount, { $add: [{ $ifNull: ['$attemptCount', 0] }, 1] });
	assert.equal(set.lastAttemptedAt && '$literal' in set.lastAttemptedAt, true);
	assert.deepEqual(set.currentCode, { $literal: '$status' });
});

test('a rejected attempt never completes or downgrades the level', async () => {
	const { client, attempts, progress, updates } = fakes();
	await recordAttempt(client, attempts, progress, input(rejected));
	const set = setOf(updates[0].update);
	assert.deepEqual(set.status, {
		$cond: [{ $eq: ['$status', 'completed'] }, 'completed', 'in_progress']
	});
	assert.equal('completedAt' in set, false);
	assert.deepEqual(set.currentError, { $literal: 'Type mismatch' });
});

test('a concurrent first write reruns the whole transaction as an update', async () => {
	const duplicate = new MongoServerError({ message: 'E11000 duplicate key', code: 11000 });
	const { client, attempts, progress, updates, transactions } = fakes({
		updateErrors: [duplicate]
	});
	await recordAttempt(client, attempts, progress, input(accepted));
	assert.equal(updates.length, 2);
	assert.equal(transactions(), 2);
});

test('other database errors are rethrown', async () => {
	const error = new MongoServerError({ message: 'boom', code: 1 });
	const { client, attempts, progress } = fakes({ updateErrors: [error] });
	await assert.rejects(recordAttempt(client, attempts, progress, input(accepted)), error);
});

test('the stored error prefers errors, then warnings, then comparator messages, then the reason', () => {
	assert.equal(attemptErrorMessage(rejected), 'Type mismatch');
	assert.equal(
		attemptErrorMessage({ ...rejected, diagnostics: [rejected.diagnostics[0]] }),
		'unused variable'
	);
	assert.equal(
		attemptErrorMessage({
			...accepted,
			accepted: false,
			reason: 'verification_failed',
			verification: { ...accepted.verification!, message: 'axiom not allowed' }
		}),
		'axiom not allowed'
	);
	assert.equal(
		attemptErrorMessage({ ...rejected, diagnostics: [], reason: 'missing_theorem' }),
		'missing_theorem'
	);
});
