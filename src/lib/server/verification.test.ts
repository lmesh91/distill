import assert from 'node:assert/strict';
import { mkdtemp, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { verifyLean } from './verification.ts';
import { createSubmissionHandler } from './submissions.ts';
import { parseLeanDiagnostics } from './leanDiagnostics.ts';

const target = { theoremName: 'target', challengeSource: 'theorem target : True := by sorry' };

test('a clean proof passes comparator and reports its transitive dependencies', async () => {
	const result = await verifyLean(
		'theorem helper : True := by trivial\ntheorem target : True := helper',
		target
	);
	assert.equal(result.accepted, true, JSON.stringify(result));
	assert.equal(result.reason, 'accepted');
	assert.deepEqual(result.diagnostics, []);
	assert.ok(result.verification?.dependencies.includes('helper'));
	assert.ok(result.verification?.dependencies.includes('True.intro'));
	assert.deepEqual(result.verification?.axioms, []);
});

test('project imports and qualified theorem names work', async () => {
	const challengeSource =
		'import Distill\nnamespace Exercise\ntheorem target : hello = "world" := by sorry\nend Exercise';
	const result = await verifyLean(challengeSource.replace('sorry', 'rfl'), {
		theoremName: 'Exercise.target',
		challengeSource
	});
	assert.equal(result.accepted, true, JSON.stringify(result));
});

test('errors and every emitted warning reject otherwise plausible submissions', async () => {
	for (const source of [
		'theorem target : True := by missingTactic',
		'theorem target : True := by sorry',
		'def unused (x : Nat) : Nat := 1\ntheorem target : True := by trivial',
		'#eval IO.print "prefix"\ndef unused (x : Nat) : Nat := 1\ntheorem target : True := True.intro'
	]) {
		const result = await verifyLean(source, target);
		assert.equal(result.accepted, false, source);
		assert.equal(result.reason, 'diagnostics', JSON.stringify(result));
		assert.ok(result.diagnostics.some((d) => d.severity === 'error' || d.severity === 'warning'));
	}
});

test('informational diagnostics and arbitrary stdout are not warnings', async () => {
	const result = await verifyLean(
		'#check Nat\n#eval IO.println "warning: ordinary text"\ntheorem target : True := by trivial',
		target
	);
	assert.equal(result.accepted, true, JSON.stringify(result));
	assert.ok(result.diagnostics.some((d) => d.severity === 'information'));
});

test('missing, renamed, or differently namespaced theorems are rejected', async () => {
	for (const source of [
		'theorem other : True := by trivial',
		'namespace Other\ntheorem target : True := by trivial\nend Other',
		'example : True := by trivial',
		'#eval IO.println "Your solution is okay!"'
	]) {
		const result = await verifyLean(source, target);
		assert.equal(result.compiled, true);
		assert.equal(result.accepted, false);
		assert.equal(result.reason, 'missing_theorem', JSON.stringify(result));
	}
});

test('comparator requires the exact target type and declaration kind', async () => {
	for (const source of [
		'theorem target : True ∧ True := ⟨True.intro, True.intro⟩',
		'theorem target (_h : True) : True := True.intro',
		'set_option linter.defProp false\ndef target : True := True.intro'
	]) {
		const result = await verifyLean(source, target);
		assert.equal(result.compiled, true, JSON.stringify(result));
		assert.equal(result.accepted, false);
		assert.equal(result.reason, 'verification_failed', JSON.stringify(result));
	}
});

test('comparator checks the definitions behind a matching theorem statement', async () => {
	const challengeSource = 'def goal : Prop := True\ntheorem target : goal := by sorry';
	const result = await verifyLean(
		'def goal : Prop := False → False\ntheorem target : goal := fun h => h',
		{
			...target,
			challengeSource
		}
	);
	assert.equal(result.accepted, false);
	assert.equal(result.reason, 'verification_failed');
	assert.match(result.verification?.message ?? '', /Const does not match/);
});

test('new axioms are rejected even when unused or hidden behind helper lemmas', async () => {
	for (const source of [
		'axiom cheat : False\ntheorem helper : True := False.elim cheat\ntheorem target : True := helper',
		'axiom unusedCheat : False\ntheorem target : True := True.intro',
		'private axiom unusedCheat : False\ntheorem target : True := True.intro',
		'module\nprivate axiom unusedCheat : False\npublic theorem target : True := True.intro',
		'axiom target : True'
	]) {
		const result = await verifyLean(source, target);
		assert.equal(result.compiled, true, JSON.stringify(result));
		assert.equal(result.reason, 'introduced_axioms', JSON.stringify(result));
		assert.equal(result.accepted, false);
		assert.ok(result.verification?.introducedAxioms.length);
	}
});

test('disabling sorry warnings cannot bypass comparator axiom checks', async () => {
	const result = await verifyLean(
		'set_option warn.sorry false\ntheorem target : True := by sorry',
		target
	);
	assert.equal(result.compiled, true);
	assert.deepEqual(result.diagnostics, []);
	assert.equal(result.accepted, false);
	assert.equal(result.reason, 'verification_failed');
	assert.ok(result.verification?.axioms.includes('sorryAx'));
});

test('standard classical axioms are allowed and reported', async () => {
	const challengeSource = 'theorem target (p : Prop) : p ∨ ¬p := by sorry';
	const result = await verifyLean('theorem target (p : Prop) : p ∨ ¬p := Classical.em p', {
		...target,
		challengeSource
	});
	assert.equal(result.accepted, true, JSON.stringify(result));
	assert.ok(result.verification?.axioms.includes('Classical.choice'));
});

test('kernel replay rejects a forged proof that compiles with no diagnostics', async () => {
	const source = `import Lean
open Lean Elab Command
run_elab do
  let decl := Declaration.thmDecl {
    name := \`target
    levelParams := []
    type := mkConst \`\`False
    value := mkConst \`\`True.intro
  }
  let env ← getEnv
  match env.addDeclCore 0 0 decl none false with
  | .ok env => setEnv env
  | .error _ => throwError "insertion failed"
`;
	const result = await verifyLean(source, {
		...target,
		challengeSource: 'import Lean\ntheorem target : False := by sorry'
	});
	assert.equal(result.compiled, true, JSON.stringify(result));
	assert.deepEqual(result.diagnostics, []);
	assert.equal(result.accepted, false);
	assert.equal(result.reason, 'verification_failed');
	assert.match(result.verification?.message ?? '', /Lean default/);
});

test('the solution cannot import the challenge theorem', async () => {
	const result = await verifyLean('import Challenge', target);
	assert.equal(result.accepted, false);
	assert.equal(result.reason, 'diagnostics');
});

test('a submission cannot alter the challenge or the stored exports', async () => {
	const source = `
#eval show IO Unit from do
  for path in (["/exports/Challenge.ndjson", "/submission/Challenge.lean", "/submission/Solution.lean"] : List System.FilePath) do
    try
      IO.FS.writeFile path "theorem target : False → False := fun h => h"
    catch _ => pure ()
theorem target : False → False := fun h => h
`;
	const result = await verifyLean(source, target);
	assert.equal(result.compiled, true);
	assert.equal(result.accepted, false);
	assert.equal(result.reason, 'verification_failed');
});

test('fresh artifacts are isolated across concurrent requests and cleaned on rejection', async () => {
	const directory = await mkdtemp(join(tmpdir(), 'distill-verification-test-'));
	const previous = process.env.TMPDIR;
	process.env.TMPDIR = directory;
	try {
		const results = await Promise.all([
			verifyLean('theorem target : True := True.intro', target),
			verifyLean('theorem target : True := by sorry', target),
			verifyLean('theorem target : True := True.intro', target)
		]);
		assert.deepEqual(
			results.map((r) => r.accepted),
			[true, false, true]
		);
		assert.deepEqual(await readdir(directory), []);
		await assert.rejects(
			verifyLean('theorem target : True := True.intro', { ...target, challengeSource: 'broken' })
		);
		assert.deepEqual(await readdir(directory), []);
		const lockedScratch = await verifyLean(
			`#eval show IO Unit from do
  IO.FS.createDirAll "/work/locked/nested"
  IO.setAccessRights "/work/locked/nested" {}
  IO.setAccessRights "/work/locked" {}
theorem target : True := True.intro`,
			target
		);
		assert.equal(lockedScratch.accepted, true, JSON.stringify(lockedScratch));
		assert.deepEqual(await readdir(directory), []);
	} finally {
		if (previous === undefined) delete process.env.TMPDIR;
		else process.env.TMPDIR = previous;
		await rm(directory, { recursive: true, force: true });
	}
});

test('diagnostic parsing ignores non-diagnostic output and preserves multiline Unicode messages', () => {
	const diagnostic = {
		severity: 'error',
		data: 'α is not defined\nTry another name.',
		fileName: 'Solution.lean',
		pos: { line: 2, column: 4 },
		endPos: { line: 2, column: 5 }
	};
	assert.deepEqual(
		parseLeanDiagnostics(
			['hello', '{"accepted":true}', JSON.stringify(diagnostic), '{'].join('\n')
		),
		[
			{
				severity: 'error',
				message: diagnostic.data,
				fileName: 'Solution.lean',
				position: diagnostic.pos,
				endPosition: diagnostic.endPos
			},
			{
				severity: 'error',
				message: 'Could not read Lean diagnostics from compiler output.'
			}
		]
	);
});

async function submit(
	body: unknown,
	load: Parameters<typeof createSubmissionHandler>[0] = async (slug: string) =>
		slug === 'test' ? { verification: target } : null
) {
	return createSubmissionHandler(load)({
		request: new Request('http://localhost/api/submissions', {
			method: 'POST',
			headers: { 'content-type': 'application/json' },
			body: JSON.stringify(body)
		}),
		locals: { auth: () => ({ userId: 'test-user' }) }
	} as Parameters<ReturnType<typeof createSubmissionHandler>>[0]);
}

test('API selects the trusted level target and ignores client-supplied verification policy', async () => {
	const response = await submit({
		levelSlug: 'test',
		source: 'theorem target : False → False := fun h => h',
		verification: { ...target, challengeSource: 'theorem target : False → False := by sorry' },
		permitted_axioms: ['sorryAx']
	});
	assert.equal(response.status, 200);
	assert.equal(response.headers.get('cache-control'), 'no-store');
	const result = await response.json();
	assert.equal(result.accepted, false);
	assert.equal(result.reason, 'verification_failed');
});

test('API rejects unknown levels and levels without a trusted verification configuration', async () => {
	assert.equal(
		(await submit({ levelSlug: 'missing', source: 'theorem target : True := True.intro' })).status,
		404
	);
	assert.equal(
		(
			await submit(
				{ levelSlug: 'test', source: 'theorem target : True := True.intro' },
				async () => ({})
			)
		).status,
		503
	);
	assert.equal((await submit({ source: 'theorem target : True := True.intro' })).status, 400);
});
