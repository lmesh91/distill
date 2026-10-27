import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, realpath, rm, symlink, writeFile } from 'node:fs/promises';
import { createServer } from 'node:net';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { test } from 'node:test';
import { compileLean } from './lean.ts';
import { runLeanJob } from './leanJobs.ts';
import { leanLimits } from './leanLimits.ts';
import { createSubmissionHandler } from './submissions.ts';

const POST = createSubmissionHandler(async () => ({
	verification: { theoremName: 'target', challengeSource: 'theorem target : 2 + 2 = 4 := by sorry' }
}));

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
	assert.deepEqual(result, {
		compiled: true,
		exitCode: 0,
		stdout: '',
		stderr: '',
		diagnostics: []
	});
});

test('compilation errors are results, with Lean source locations and output preserved', async () => {
	const result = await compileLean('example : 1 + 1 = 3 := rfl\n');
	assert.equal(result.compiled, false);
	assert.equal(result.exitCode, 1);
	assert.equal(result.diagnostics[0].severity, 'error');
	assert.deepEqual(result.diagnostics[0].position, { line: 1, column: 23 });
	assert.match(result.stdout, /Type mismatch/);
});

test('warnings are returned as structured diagnostics', async () => {
	const result = await compileLean('example : True := by sorry\n');
	assert.equal(result.compiled, true);
	assert.equal(result.diagnostics[0].severity, 'warning');
	assert.match(result.diagnostics[0].message, /declaration uses `sorry`/);
});

test('excessive compiler output fails without returning an unbounded response', async () => {
	await assert.rejects(
		compileLean("#eval IO.println (String.ofList (List.replicate 1100000 'x'))\n"),
		/output exceeded the limit/
	);
});

test('a stuck compilation is terminated at the request deadline', async () => {
	await assert.rejects(
		runLeanJob(
			{ kind: 'compile', source: '#eval IO.sleep 60000\n' },
			{
				limits: { ...leanLimits, wallTimeMs: 1500 }
			}
		),
		/timed out|resource worker failed/
	);
});

test('host files, app files, and credentials are absent even through /proc', async () => {
	const directory = await mkdtemp(join(tmpdir(), 'distill-secret-'));
	const secret = join(directory, 'secret');
	const previous = process.env.DISTILL_SANDBOX_TEST_SECRET;
	process.env.DISTILL_SANDBOX_TEST_SECRET = 'must-not-be-visible';
	try {
		await writeFile(secret, 'must-not-be-visible');
		const result = await compileLean(`
#eval show IO Unit from do
  for path in ([${JSON.stringify(secret)}, ${JSON.stringify(resolve('package.json'))}, "/proc/1/root${secret}"] : List System.FilePath) do
    if ← System.FilePath.pathExists path then throw (IO.userError s!"host file visible: {path}")
  if (← IO.getEnv "DISTILL_SANDBOX_TEST_SECRET").isSome then throw (IO.userError "secret inherited")
  let parentEnv ← IO.FS.readFile "/proc/1/environ"
  if (parentEnv.splitOn "must-not-be-visible").length != 1 then throw (IO.userError "secret in proc")
  try
    IO.FS.writeFile ${JSON.stringify(secret)} "overwritten"
  catch _ => pure ()
`);
		assert.equal(result.compiled, true, result.stdout + result.stderr);
		assert.equal(await readFile(secret, 'utf8'), 'must-not-be-visible');
	} finally {
		if (previous === undefined) delete process.env.DISTILL_SANDBOX_TEST_SECRET;
		else process.env.DISTILL_SANDBOX_TEST_SECRET = previous;
		await rm(directory, { recursive: true, force: true });
	}
});

test('toolchain and imported libraries cannot be modified', async () => {
	const result = await compileLean(`
import Distill
#eval show IO Unit from do
  for path in (["/imports/0/Distill.olean", "/toolchain/bin/lean"] : List System.FilePath) do
    unless ← path.pathExists do throw (IO.userError s!"missing dependency: {path}")
    let mut blocked := false
    try
      let _ ← IO.FS.Handle.mk path IO.FS.Mode.append
    catch _ => blocked := true
    unless blocked do throw (IO.userError s!"writable dependency: {path}")
example : hello = "world" := rfl
`);
	assert.equal(result.compiled, true, result.stdout + result.stderr);
});

test('scratch files are writable, isolated concurrently, and discarded after exit or failure', async () => {
	const source = (value: string) => `
#eval show IO Unit from do
  for path in (["/work/submission-marker", "/tmp/submission-marker"] : List System.FilePath) do
    if ← System.FilePath.pathExists path then throw (IO.userError "previous submission visible")
    IO.FS.writeFile path "${value}"
  IO.sleep 100
  for path in (["/work/submission-marker", "/tmp/submission-marker"] : List System.FilePath) do
    unless (← IO.FS.readFile path) == "${value}" do throw (IO.userError "shared scratch space")
`;
	const results = await Promise.all([compileLean(source('first')), compileLean(source('second'))]);
	for (const result of results) assert.equal(result.compiled, true, result.stdout + result.stderr);
	assert.equal(
		(await compileLean(source('failed') + '\n#check nonexistentDeclaration')).compiled,
		false
	);
	const next = await compileLean(source('next'));
	assert.equal(next.compiled, true, next.stdout + next.stderr);
});

test('a submission cannot connect to a host loopback service', async () => {
	let connections = 0;
	const server = createServer((socket) => {
		connections++;
		socket.destroy();
	});
	await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
	try {
		const address = server.address();
		assert.ok(address && typeof address !== 'string');
		const result = await compileLean(`
import Std.Internal.UV.TCP
#eval show IO Unit from do
  let socket ← Std.Internal.UV.TCP.Socket.new
  let connection ← socket.connect (.v4 ⟨Std.Net.IPv4Addr.ofParts 127 0 0 1, ${address.port}⟩)
  match connection.result!.get with
  | .ok _ => throw (IO.userError "connected to host")
  | .error _ => pure ()
`);
		assert.equal(result.compiled, true, result.stdout + result.stderr);
		assert.equal(connections, 0);
	} finally {
		await new Promise<void>((resolve, reject) =>
			server.close((error) => (error ? reject(error) : resolve()))
		);
	}
});

async function childProcesses(marker: string) {
	const processes = await Promise.all(
		(await readdir('/proc'))
			.filter((pid) => /^\d+$/.test(pid))
			.map(async (pid) => {
				try {
					return (await readFile(`/proc/${pid}/cmdline`, 'utf8')).includes(marker)
						? pid
						: undefined;
				} catch {
					return undefined;
				}
			})
	);
	return processes.filter((pid) => pid !== undefined);
}

test('sandbox teardown kills children after success and cancellation', async () => {
	for (const timeout of [false, true]) {
		const marker = `/work/child-${crypto.randomUUID()}.lean`;
		const source = `
#eval show IO Unit from do
  IO.FS.writeFile "${marker}" "def main : IO Unit := IO.sleep 60000"
  let _ ← IO.Process.spawn { cmd := "/toolchain/bin/lean", args := #["--run", "${marker}"], stdin := .null, stdout := .null, stderr := .null }
  IO.sleep ${timeout ? 60000 : 500}
`;
		const controller = new AbortController();
		const compilation = compileLean(source, controller.signal);
		const completion = timeout ? assert.rejects(compilation, /cancelled/) : compilation;
		try {
			let children: string[] = [];
			for (let attempt = 0; attempt < 200 && children.length === 0; attempt++) {
				await delay(25);
				children = await childProcesses(marker);
			}
			assert.ok(children.length > 0, 'child started inside the sandbox');
			if (timeout) controller.abort();
			await completion;
			for (let attempt = 0; attempt < 100 && (await childProcesses(marker)).length > 0; attempt++)
				await delay(10);
			assert.deepEqual(await childProcesses(marker), []);
		} finally {
			controller.abort();
			await completion.catch(() => {});
		}
	}
});

test('sandbox setup errors fail closed and return a generic API error', async (t) => {
	const directory = await mkdtemp(join(process.cwd(), '.lean-test-bwrap-'));
	const previous = process.env.PATH;
	t.mock.method(console, 'error', () => {});
	try {
		await writeFile(
			join(directory, 'bwrap'),
			'#!/bin/sh\necho "bwrap: namespace setup denied" >&2\nexit 1\n',
			{ mode: 0o700 }
		);
		process.env.PATH = `${directory}:${previous}`;
		await assert.rejects(compileLean('example : True := by trivial'), /Lean sandbox failed/);
		const response = await submit(
			JSON.stringify({ levelSlug: 'test-level', source: 'example : True := by trivial' })
		);
		assert.equal(response.status, 503);
		assert.deepEqual(await response.json(), { error: 'Lean verification service unavailable' });
	} finally {
		process.env.PATH = previous;
		await rm(directory, { recursive: true, force: true });
	}
});

test('missing Bubblewrap never falls back to running Lean on the host', async (t) => {
	const directory = await mkdtemp(join(process.cwd(), '.lean-test-no-bwrap-'));
	const previous = process.env.PATH;
	t.mock.method(console, 'error', () => {});
	try {
		const candidates = await Promise.all(
			(previous ?? '').split(':').map((path) => realpath(join(path, 'lake')).catch(() => undefined))
		);
		const lake = candidates.find((path) => path !== undefined);
		assert.ok(lake, 'Lake is installed');
		await symlink(lake, join(directory, 'lake'));
		process.env.PATH = directory;
		await assert.rejects(compileLean('example : True := by trivial'), /spawn bwrap ENOENT/);
		const response = await submit(
			JSON.stringify({ levelSlug: 'test-level', source: 'example : True := by trivial' })
		);
		assert.equal(response.status, 503);
		assert.deepEqual(await response.json(), { error: 'Lean verification service unavailable' });
	} finally {
		if (previous === undefined) delete process.env.PATH;
		else process.env.PATH = previous;
		await rm(directory, { recursive: true, force: true });
	}
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
	const response = await submit(
		JSON.stringify({ levelSlug: 'test-level', source: 'a'.repeat(256 * 1024) })
	);
	assert.equal(response.status, 413);
});

test('submission API returns compilation outcomes for valid and invalid proofs', async () => {
	for (const [source, compiled] of [
		['theorem target : 2 + 2 = 4 := rfl\n', true],
		['theorem target : 2 + 2 = 4 := by rflx\n', false]
	] as const) {
		const response = await submit(JSON.stringify({ levelSlug: 'test-level', source }));
		assert.equal(response.status, 200);
		assert.equal(response.headers.get('cache-control'), 'no-store');
		const result = await response.json();
		assert.equal(result.compiled, compiled);
		assert.equal(result.accepted, compiled);
	}
});

test('runtime failures reject in the service and become a generic API error', async (t) => {
	const previous = process.env.LEAN_PROJECT_DIR;
	process.env.LEAN_PROJECT_DIR = '/nonexistent-distill-lean-project';
	t.mock.method(console, 'error', () => {});
	try {
		await assert.rejects(compileLean('example : True := by trivial'), /ENOENT/);
		const response = await submit(
			JSON.stringify({ levelSlug: 'test-level', source: 'example : True := by trivial' })
		);
		assert.equal(response.status, 503);
		assert.deepEqual(await response.json(), { error: 'Lean verification service unavailable' });
	} finally {
		if (previous === undefined) delete process.env.LEAN_PROJECT_DIR;
		else process.env.LEAN_PROJECT_DIR = previous;
	}
});
