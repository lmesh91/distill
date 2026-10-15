import assert from 'node:assert/strict';
import { test } from 'node:test';
import { compileLean } from './lean.ts';
import { POST } from '../../routes/api/submissions/+server.ts';

function submit(body: string, userId: string | null = 'test-user', type = 'application/json') {
	return POST({
		request: new Request('http://localhost/api/submissions', {
			method: 'POST',
			headers: { 'content-type': type },
			body
		}),
		locals: { auth: () => ({ userId }) }
	} as Parameters<typeof POST>[0]);
}

test('batch compiler checks source using the pinned project and its imports', async () => {
	const result = await compileLean('import Distill\nexample : hello = "world" := rfl\n');
	assert.deepEqual(result, { compiled: true, exitCode: 0, stdout: '', stderr: '' });
});

test('compilation errors are results, with Lean source locations and output preserved', async () => {
	const result = await compileLean('example : 1 + 1 = 3 := rfl\n');
	assert.equal(result.compiled, false);
	assert.equal(result.exitCode, 1);
	assert.match(result.stdout, /<stdin>:1:23: error:/);
	assert.match(result.stdout, /Type mismatch/);
});

test('warnings are retained for the later proof-validation layer', async () => {
	const result = await compileLean('example : True := by sorry\n');
	assert.equal(result.compiled, true);
	assert.match(result.stdout, /warning: declaration uses `sorry`/);
});

test('excessive compiler output fails without returning an unbounded response', async () => {
	await assert.rejects(
		compileLean("#eval IO.println (String.ofList (List.replicate 1100000 'x'))\n"),
		/output exceeded the limit/
	);
});

test('a stuck compilation is terminated at the deadline', async (t) => {
	t.mock.timers.enable({ apis: ['setTimeout'] });
	const result = assert.rejects(compileLean('#eval IO.sleep 60000\n'), /timed out/);
	t.mock.timers.tick(30_000);
	await result;
});

test('parallel submissions do not share declarations or compiler state', async () => {
	const results = await Promise.all([
		compileLean('def submissionOnly : Nat := 42\nexample : submissionOnly = 42 := rfl\n'),
		compileLean('#check submissionOnly\n'),
		compileLean('example (α : Type) (x : α) : x = x := rfl\n')
	]);
	assert.deepEqual(
		results.map((result) => result.compiled),
		[true, false, true]
	);
	assert.match(results[1].stdout, /Unknown identifier|Unknown constant/);
});

test('submission API requires authentication before accepting input', async () => {
	const response = await submit('not JSON', null);
	assert.equal(response.status, 401);
});

test('submission API validates its content type, JSON, and source', async () => {
	assert.equal((await submit('{}', 'test-user', 'text/plain')).status, 415);
	for (const body of ['{', 'null', '[]', '{}', '{"source":42}', '{"source":"  "}']) {
		assert.equal((await submit(body)).status, 400, body);
	}
});

test('submission API limits request bodies without relying on Content-Length', async () => {
	const response = await submit(JSON.stringify({ source: 'a'.repeat(256 * 1024) }));
	assert.equal(response.status, 413);
});

test('submission API returns compilation outcomes for valid and invalid proofs', async () => {
	for (const [source, compiled] of [
		['example : 2 + 2 = 4 := rfl\n', true],
		['example : 2 + 2 = 5 := rfl\n', false]
	] as const) {
		const response = await submit(JSON.stringify({ source }));
		assert.equal(response.status, 200);
		assert.equal(response.headers.get('cache-control'), 'no-store');
		const result = await response.json();
		assert.equal(result.compiled, compiled);
		assert.equal(result.exitCode, compiled ? 0 : 1);
	}
});

test('runtime failures reject in the service and become a generic API error', async (t) => {
	const previous = process.env.LEAN_PROJECT_DIR;
	process.env.LEAN_PROJECT_DIR = '/nonexistent-distill-lean-project';
	t.mock.method(console, 'error', () => {});
	try {
		await assert.rejects(compileLean('example : True := by trivial'), /ENOENT/);
		const response = await submit(JSON.stringify({ source: 'example : True := by trivial' }));
		assert.equal(response.status, 503);
		assert.deepEqual(await response.json(), { error: 'Lean compilation service unavailable' });
	} finally {
		if (previous === undefined) delete process.env.LEAN_PROJECT_DIR;
		else process.env.LEAN_PROJECT_DIR = previous;
	}
});
