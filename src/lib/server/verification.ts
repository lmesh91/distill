import { chmod, mkdtemp, mkdir, readdir, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, delimiter } from 'node:path';
import { runLeanProcess } from './lean.ts';
import { parseLeanDiagnostics } from './leanDiagnostics.ts';
import { resolveLeanEnvironment, sandboxArgs, type LeanEnvironment } from './leanSandbox.ts';
import type { VerificationResult, VerificationTarget } from '../types/submission.ts';

const permittedAxioms = ['propext', 'Quot.sound', 'Classical.choice'];
const maxExportBytes = 32 * 1024 * 1024;

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

interface Inspection {
	theoremExists: boolean;
	dependencies: string[];
	axioms: string[];
	introducedAxioms: string[];
}

async function removeArtifacts(directory: string): Promise<void> {
	// All sandbox processes have exited. User code may have chmod'ed scratch directories
	// to 000; restore traversal rights before deletion, without following any symlinks.
	async function restoreAccess(path: string): Promise<void> {
		await chmod(path, 0o700);
		for (const entry of await readdir(path, { withFileTypes: true })) {
			if (entry.isDirectory()) await restoreAccess(join(path, entry.name));
		}
	}
	await restoreAccess(directory);
	await rm(directory, { recursive: true, force: true });
}

async function compileAndExport(
	environment: LeanEnvironment,
	directory: string,
	module: 'Challenge' | 'Solution',
	source: string,
	theoremName: string
) {
	const input = join(directory, `${module}-input`);
	const work = join(directory, `${module}-work`);
	await mkdir(input);
	await mkdir(work);
	await writeFile(join(input, `${module}.lean`), source);
	const compilation = await runLeanProcess(
		'bwrap',
		sandboxArgs(environment, {
			command: [
				'/toolchain/bin/lean',
				'--json',
				'--root=/submission',
				'-o',
				`/work/${module}.olean`,
				`/submission/${module}.lean`
			],
			readOnly: [[input, '/submission']],
			work
		})
	);
	const diagnostics = parseLeanDiagnostics(compilation.stdout);
	if (
		compilation.exitCode !== 0 ||
		(module === 'Solution' && diagnostics.some((d) => d.severity !== 'information'))
	) {
		return { compilation, diagnostics, exportPath: null };
	}
	// No untrusted .olean is ever loaded into the web server or comparator. The fresh,
	// read-only export sandbox can only return inert NDJSON through its bounded stdout.
	const exported = await runLeanProcess(
		'bwrap',
		sandboxArgs(environment, {
			command: ['/verifier', 'export', module, theoremName],
			readOnly: [
				[environment.verifier, '/verifier'],
				[work, '/work']
			]
		}),
		{ outputLimit: maxExportBytes }
	);
	if (exported.exitCode !== 0) {
		if (module === 'Challenge') throw new Error('Could not export the trusted challenge');
		return { compilation, diagnostics, exportPath: null };
	}
	const exportPath = join(directory, `${module}.ndjson`);
	await writeFile(exportPath, exported.stdout);
	return { compilation, diagnostics, exportPath };
}

/** Verify one submission against a server-selected, trusted level challenge. */
export async function verifyLean(
	source: string,
	target: VerificationTarget
): Promise<VerificationResult> {
	if (!isVerificationTarget(target)) throw new Error('Level has no verification target');
	const environment = await resolveLeanEnvironment();
	const directory = await mkdtemp(join(tmpdir(), 'distill-verification-'));
	try {
		// Finish the trusted export before compiling any user code. The two compilations
		// have separate inputs, scratch filesystems, processes, and writable directories.
		const challenge = await compileAndExport(
			environment,
			directory,
			'Challenge',
			target.challengeSource,
			target.theoremName
		);
		if (!challenge.exportPath) throw new Error('Trusted challenge did not compile');
		const solution = await compileAndExport(
			environment,
			directory,
			'Solution',
			source,
			target.theoremName
		);
		const base = {
			compiled: solution.compilation.exitCode === 0,
			diagnostics: solution.diagnostics
		};
		if (!base.compiled || base.diagnostics.some((d) => d.severity !== 'information')) {
			return { ...base, accepted: false, reason: 'diagnostics', verification: null };
		}
		if (!solution.exportPath) {
			return { ...base, accepted: false, reason: 'verification_failed', verification: null };
		}
		const inspection = await runLeanProcess(
			'bwrap',
			sandboxArgs(environment, {
				command: [
					'/verifier',
					'inspect',
					'/exports/Challenge.ndjson',
					'/exports/Solution.ndjson',
					target.theoremName
				],
				readOnly: [
					[environment.verifier, '/verifier'],
					[directory, '/exports']
				]
			})
		);
		if (inspection.exitCode !== 0) {
			return { ...base, accepted: false, reason: 'verification_failed', verification: null };
		}
		const details: Inspection = JSON.parse(inspection.stdout);
		const verification = {
			theoremName: target.theoremName,
			dependencies: details.dependencies,
			axioms: details.axioms,
			introducedAxioms: details.introducedAxioms
		};
		if (!details.theoremExists) {
			return { ...base, accepted: false, reason: 'missing_theorem', verification };
		}
		if (details.introducedAxioms.length) {
			return { ...base, accepted: false, reason: 'introduced_axioms', verification };
		}
		const config = join(directory, 'comparator.json');
		await writeFile(
			config,
			JSON.stringify({
				challenge_module: 'Challenge',
				solution_module: 'Solution',
				theorem_names: [target.theoremName],
				permitted_axioms: permittedAxioms
			})
		);
		// This is Lean's trusted comparator, consuming exports only. It never builds
		// user code or loads user-produced oleans; its kernel replay has its own sandbox.
		const comparison = await runLeanProcess(
			join(environment.toolchain, 'bin/lake'),
			[
				'comparator',
				'--config',
				config,
				'--challenge-from-export',
				challenge.exportPath,
				'--solution-from-export',
				solution.exportPath
			],
			{
				cwd: directory,
				env: {
					PATH: [join(environment.toolchain, 'bin'), process.env.PATH].join(delimiter),
					TMPDIR: directory
				}
			}
		);
		if (
			comparison.exitCode === 2 ||
			/(?:^bwrap:|error while loading shared libraries)/m.test(comparison.stderr)
		) {
			throw new Error('Lean comparator unavailable');
		}
		const accepted = comparison.exitCode === 0;
		return {
			...base,
			accepted,
			reason: accepted ? 'accepted' : 'verification_failed',
			verification: {
				...verification,
				...(accepted ? {} : { message: comparison.stderr.trim() || comparison.stdout.trim() })
			}
		};
	} finally {
		await removeArtifacts(directory);
	}
}
