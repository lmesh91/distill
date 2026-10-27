import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
	SaveError,
	createAutosaver,
	describeSaveState,
	timeSince,
	saveLevelCode,
	type SaveState
} from '../../../src/lib/levels/autosave.ts';

// Lets queued promise callbacks run after advancing fake timers.
const settle = () => new Promise((resolve) => setImmediate(resolve));

function setup(save?: (code: string) => Promise<void>) {
	const saves: { code: string; savedAt: number; keepalive: boolean }[] = [];
	const states: SaveState[] = [];
	let clock = 1_000;
	const saver = createAutosaver({
		delay: 500,
		retryDelay: 5000,
		now: () => clock,
		onstate: (state) => states.push(state),
		save: async (code, savedAt, { keepalive }) => {
			saves.push({ code, savedAt, keepalive });
			await save?.(code);
		}
	});
	return { saver, saves, states, tick: (ms: number) => (clock += ms) };
}

test('saves 500 ms after the last edit, once, with the latest code', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	const { saver, saves, states } = setup();

	saver.schedule('a');
	t.mock.timers.tick(300);
	saver.schedule('ab');
	t.mock.timers.tick(300);
	saver.schedule('abc');
	t.mock.timers.tick(499);
	await settle();
	assert.equal(saves.length, 0, 'still typing: nothing saved yet');

	t.mock.timers.tick(1);
	await settle();
	assert.deepEqual(
		saves.map((s) => s.code),
		['abc']
	);
	assert.deepEqual(
		states.map((s) => s.kind),
		['saving', 'saved']
	);
});

test('flush saves a waiting edit immediately, and does nothing when there is none', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	const { saver, saves } = setup();

	saver.schedule('leaving soon');
	await saver.flush({ keepalive: true });
	assert.deepEqual(saves, [{ code: 'leaving soon', savedAt: 1000, keepalive: true }]);

	await saver.flush();
	t.mock.timers.tick(1000);
	await settle();
	assert.equal(saves.length, 1, 'no duplicate save after flushing');
});

test('one autosaver per level: flushing the old level saves its code there, not to the new level', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	const saved: Record<string, string[]> = { 'level-1': [], 'level-2': [] };
	const forLevel = (id: string) =>
		createAutosaver({
			onstate: () => {},
			save: async (code) => {
				saved[id].push(code);
			}
		});

	const level1 = forLevel('level-1');
	level1.schedule('-- level one work');
	// The user switches levels before the 500 ms delay ends.
	const leaving = level1.dispose();
	const level2 = forLevel('level-2');
	await leaving;
	level1.schedule('ignored after dispose');
	t.mock.timers.tick(1000);
	await settle();

	assert.deepEqual(saved, { 'level-1': ['-- level one work'], 'level-2': [] });
	assert.equal(level2.hasPending, false);
});

test('a failed save keeps the code and retries; a newer edit replaces it', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	let fail = true;
	const { saver, saves, states } = setup(async () => {
		if (fail) throw new SaveError('Could not reach the server.', true);
	});

	saver.schedule('v1');
	t.mock.timers.tick(500);
	await settle();
	assert.deepEqual(states.at(-1), {
		kind: 'error',
		message: 'Could not reach the server.',
		retrying: true
	});
	assert.equal(saver.hasPending, true);

	fail = false;
	t.mock.timers.tick(5000);
	await settle();
	assert.deepEqual(
		saves.map((s) => s.code),
		['v1', 'v1']
	);
	assert.equal(states.at(-1)?.kind, 'saved');

	fail = true;
	saver.schedule('v2');
	t.mock.timers.tick(500);
	await settle();
	fail = false;
	saver.schedule('v3');
	t.mock.timers.tick(500);
	await settle();
	assert.deepEqual(
		saves.map((s) => s.code),
		['v1', 'v1', 'v2', 'v3']
	);
});

test('errors that will not fix themselves are shown without retrying', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	const { saver, saves, states } = setup(async () => {
		throw new SaveError('Sign in again to save your work.', false);
	});

	saver.schedule('code');
	t.mock.timers.tick(500);
	await settle();
	t.mock.timers.tick(60_000);
	await settle();
	assert.equal(saves.length, 1);
	assert.deepEqual(states.at(-1), {
		kind: 'error',
		message: 'Sign in again to save your work.',
		retrying: false
	});
});

test('describeSaveState picks the icon and the short time for the editor title bar', () => {
	const at = 1_000_000;
	const minute = 60_000;
	assert.deepEqual(describeSaveState({ kind: 'idle' }, null, at), {
		icon: 'not-saved',
		label: 'Not saved yet',
		time: ''
	});
	assert.deepEqual(describeSaveState({ kind: 'saving' }, at, at + 5 * minute), {
		icon: 'saving',
		label: 'Saving…',
		time: '5 min ago'
	});
	assert.deepEqual(describeSaveState({ kind: 'saved', at }, at, at + 59_000), {
		icon: 'saved',
		label: 'Saved just now',
		time: 'Just now'
	});
	assert.deepEqual(
		describeSaveState(
			{ kind: 'error', message: 'Could not save.', retrying: true },
			at,
			at + minute
		),
		{ icon: 'error', label: 'Could not save. Retrying…', time: 'Last saved 1 min ago' }
	);
	assert.equal(
		describeSaveState({ kind: 'error', message: 'Could not save.', retrying: false }, null, at)
			.time,
		'Not saved'
	);
	// loading another level's save shows the spinner whatever the old state was
	assert.equal(describeSaveState({ kind: 'saved', at }, at, at, true).icon, 'saving');
});

test('timeSince gives short labels', () => {
	const at = 0;
	assert.equal(timeSince(at, 59_000), 'just now');
	assert.equal(timeSince(at, 60_000), '1 min ago');
	assert.equal(timeSince(at, 2 * 3_600_000), '2 hr ago');
	assert.equal(timeSince(at, 86_400_000), '1 day ago');
	assert.equal(timeSince(at, 3 * 86_400_000), '3 days ago');
	assert.equal(timeSince(5_000, 0), 'just now'); // clock skew never shows a negative time
});

test('saveLevelCode sends PUT /api/levels/:id/progress and maps status codes', async () => {
	const requests: { url: string; init: RequestInit }[] = [];
	const fakeFetch = (status: number) =>
		(async (url: string, init: RequestInit) => {
			requests.push({ url, init });
			return new Response(null, { status });
		}) as unknown as typeof fetch;

	await saveLevelCode('abc123', 'rfl', 42, { keepalive: true }, fakeFetch(204));
	assert.equal(requests[0].url, '/api/levels/abc123/progress');
	assert.equal(requests[0].init.method, 'PUT');
	assert.deepEqual(JSON.parse(requests[0].init.body as string), { code: 'rfl', savedAt: 42 });
	assert.equal(requests[0].init.keepalive, true);

	await saveLevelCode('abc123', 'rfl', 42, {}, fakeFetch(409)); // newer save exists: fine

	for (const [status, retryable] of [
		[401, false],
		[404, false],
		[413, false],
		[400, false],
		[503, true]
	] as const) {
		await assert.rejects(
			saveLevelCode('abc123', 'rfl', 42, {}, fakeFetch(status)),
			(error: unknown) => error instanceof SaveError && error.retryable === retryable
		);
	}

	const offline = (async () => {
		throw new TypeError('Failed to fetch');
	}) as unknown as typeof fetch;
	await assert.rejects(
		saveLevelCode('abc123', 'rfl', 42, {}, offline),
		(error: unknown) => error instanceof SaveError && error.retryable
	);
});
