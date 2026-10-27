import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { test } from 'node:test';
import { createAdmissionGate, LeanBusyError, runLeanJob } from './leanJobs.ts';
import { leanLimits } from './leanLimits.ts';
import { compileLean } from './lean.ts';
import { createSubmissionHandler } from './submissions.ts';

const target = { theoremName: 'target', challengeSource: 'theorem target : True := by sorry' };

test('admission rejects excess jobs immediately and releases slots on success and failure', async () => {
	const admit = createAdmissionGate(1);
	const pending = Promise.withResolvers<void>();
	const first = admit(() => pending.promise);
	await assert.rejects(
		admit(async () => assert.fail('must not start')),
		LeanBusyError
	);
	pending.resolve();
	await first;
	await assert.rejects(
		admit(async () => {
			throw new Error('startup failed');
		}),
		/startup failed/
	);
	assert.equal(await admit(async () => 42), 42);
});

test('the API returns Retry-After when all submission slots are occupied', async () => {
	const jobs = Promise.all(
		Array.from({ length: leanLimits.maxConcurrent }, () =>
			compileLean('#eval IO.sleep 500\nexample : True := by trivial')
		)
	);
	try {
		const handler = createSubmissionHandler(async () => ({ verification: target }));
		const response = await handler({
			request: new Request('http://localhost/api/submissions', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ levelSlug: 'test', source: 'theorem target : True := True.intro' })
			}),
			locals: { auth: () => ({ userId: 'test-user' }) }
		} as Parameters<typeof handler>[0]);
		assert.equal(response.status, 503);
		assert.equal(response.headers.get('retry-after'), '1');
		assert.match((await response.json()).error, /busy/);
	} finally {
		await jobs;
	}
	assert.equal((await compileLean('example : True := by trivial')).compiled, true);
});

test('worker refuses to compile without enforced resource controls', async () => {
	const { stdout } = await promisify(execFile)(process.execPath, [
		'dist/lean-worker/server/leanWorker.js',
		JSON.stringify(leanLimits)
	]);
	const response = JSON.parse(stdout);
	assert.equal(response.ok, false);
	assert.match(response.error, /resource limits|ENOENT|cgroup/);
});

test('memory exhaustion is contained and a later submission still succeeds', async () => {
	await assert.rejects(
		runLeanJob(
			{
				kind: 'compile',
				source: '#eval IO.println (Array.replicate (128 * 1024 * 1024) (42 : UInt64)).size'
			},
			{ limits: { ...leanLimits, memoryBytes: 256 * 1024 * 1024 } }
		),
		/worker failed|terminated/
	);
	assert.equal((await compileLean('example : True := by trivial')).compiled, true);
});

test('scratch quota includes files in /tmp and /work and resets between requests', async () => {
	const result = await runLeanJob(
		{
			kind: 'compile',
			source: `
#eval show IO Unit from do
  let block := String.ofList (List.replicate (1024 * 1024) 'x')
  let mut full := false
  for i in [:32] do
    try
      IO.FS.writeFile s!"/tmp/data-{i}" block
      IO.FS.writeFile s!"/work/data-{i}" block
    catch _ => full := true
  unless full do throw (IO.userError "scratch quota was not enforced")
`
		},
		{ limits: { ...leanLimits, scratchBytes: 8 * 1024 * 1024 } }
	);
	assert.equal(result.compiled, true, result.stdout + result.stderr);
	assert.equal(
		(
			await compileLean(`
#eval show IO Unit from do
  if ← System.FilePath.pathExists "/tmp/data-0" then throw (IO.userError "scratch leaked")
`)
		).compiled,
		true
	);
});

test('process quota blocks excessive children within a submission', async () => {
	await assert.rejects(
		runLeanJob({
			kind: 'compile',
			source: `
#eval show IO Unit from do
  IO.FS.writeFile "/work/sleep.lean" "def main : IO Unit := IO.sleep 60000"
  let mut limited := false
  for _ in [:80] do
    try
      let _ ← IO.Process.spawn { cmd := "/toolchain/bin/lean", args := #["-j1", "--run", "/work/sleep.lean"], stdin := .null, stdout := .null, stderr := .null }
    catch _ => limited := true
  unless limited do throw (IO.userError "process quota was not enforced")
`
		}),
		/process limit exceeded/
	);
});

test('one deadline covers trusted preparation and user compilation together', async () => {
	const started = Date.now();
	await assert.rejects(
		runLeanJob(
			{
				kind: 'verify',
				source: '#eval IO.sleep 3000\ntheorem target : True := True.intro',
				target: { ...target, challengeSource: '#eval IO.sleep 3000\n' + target.challengeSource }
			},
			{ limits: { ...leanLimits, wallTimeMs: 5000 } }
		),
		/timed out|worker failed/
	);
	assert.ok(Date.now() - started < 9000, 'the deadline must not restart for the next stage');
});

test('an unavailable user manager fails closed through the API', async (t) => {
	const previous = process.env.DBUS_SESSION_BUS_ADDRESS;
	process.env.DBUS_SESSION_BUS_ADDRESS = 'unix:path=/nonexistent-distill-bus';
	t.mock.method(console, 'error', () => {});
	try {
		const handler = createSubmissionHandler(async () => ({ verification: target }));
		const response = await handler({
			request: new Request('http://localhost/api/submissions', {
				method: 'POST',
				headers: { 'content-type': 'application/json' },
				body: JSON.stringify({ levelSlug: 'test', source: 'theorem target : True := True.intro' })
			}),
			locals: { auth: () => ({ userId: 'test-user' }) }
		} as Parameters<typeof handler>[0]);
		assert.equal(response.status, 503);
		assert.deepEqual(await response.json(), { error: 'Lean verification service unavailable' });
	} finally {
		if (previous === undefined) delete process.env.DBUS_SESSION_BUS_ADDRESS;
		else process.env.DBUS_SESSION_BUS_ADDRESS = previous;
	}
});
