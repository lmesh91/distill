import { execFile, spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { resolve } from 'node:path';
import { promisify } from 'node:util';
import { leanLimits, type LeanLimits } from './leanLimits.ts';
import type { CompilationResult } from './leanRuntime.ts';
import type { VerificationResult, VerificationTarget } from '../types/submission.ts';

const execFileAsync = promisify(execFile);

export type LeanJob =
	| { kind: 'compile'; source: string }
	| { kind: 'verify'; source: string; target: VerificationTarget };
type JobResult<T extends LeanJob> = T extends { kind: 'compile' }
	? CompilationResult
	: VerificationResult;

export class LeanBusyError extends Error {
	constructor() {
		super('Lean verification capacity is full');
	}
}

/** No waiting queue: a burst must not retain an unbounded number of source buffers. */
export function createAdmissionGate(capacity: number) {
	let active = 0;
	return async function admit<T>(job: () => Promise<T>): Promise<T> {
		if (active >= capacity) throw new LeanBusyError();
		active++;
		try {
			return await job();
		} finally {
			active--;
		}
	};
}

const admit = createAdmissionGate(leanLimits.maxConcurrent);

/** One cgroup and one private tmpfs cover ALL stages, including Lake and comparator. */
export function runLeanJob<T extends LeanJob>(
	job: T,
	{ signal, limits = leanLimits }: { signal?: AbortSignal; limits?: LeanLimits } = {}
): Promise<JobResult<T>> {
	return admit(async () => {
		if (process.platform !== 'linux')
			throw new Error('Lean resource limits require Linux and systemd');
		signal?.throwIfAborted();
		const input = JSON.stringify(job);
		if (Buffer.byteLength(input) > 1024 * 1024)
			throw new Error('Lean worker input exceeded the limit');
		const unit = `distill-lean-${randomUUID()}.service`;
		const environment = {
			PATH: process.env.PATH ?? '/usr/bin:/bin',
			HOME: process.env.HOME ?? '/',
			...(process.env.ELAN_HOME ? { ELAN_HOME: process.env.ELAN_HOME } : {}),
			LEAN_PROJECT_DIR: resolve(process.env.LEAN_PROJECT_DIR ?? 'lean'),
			TMPDIR: '/tmp'
		};
		const args = [
			'--user',
			'--quiet',
			'--wait',
			'--pipe',
			'--collect',
			'--expand-environment=no',
			`--unit=${unit}`,
			'--property=Type=exec',
			`--property=RuntimeMaxSec=${limits.wallTimeMs}ms`,
			'--property=TimeoutStartSec=5s',
			'--property=TimeoutStopSec=1s',
			'--property=KillMode=control-group',
			'--property=KillSignal=SIGKILL',
			'--property=OOMPolicy=kill',
			`--property=MemoryMax=${limits.memoryBytes}`,
			'--property=MemorySwapMax=0',
			`--property=CPUQuota=${limits.cpuPercent}%`,
			`--property=TasksMax=${limits.tasks}`,
			'--property=LimitCORE=0',
			'--property=PrivateUsers=yes',
			`--property=TemporaryFileSystem=/tmp:rw,nosuid,nodev,size=${limits.scratchBytes},nr_inodes=${limits.scratchInodes},mode=1777`,
			'--',
			'/usr/bin/env',
			'-i',
			...Object.entries(environment).map(([key, value]) => `${key}=${value}`),
			process.execPath,
			resolve('dist/lean-worker/server/leanWorker.js'),
			JSON.stringify(limits)
		];
		return new Promise<JobResult<T>>((resolveResult, reject) => {
			// The client needs the user's bus; the worker receives only the allowlist above.
			const child = spawn('/usr/bin/systemd-run', args, { stdio: ['pipe', 'pipe', 'pipe'] });
			const stdout: Buffer[] = [];
			const stderr: Buffer[] = [];
			let bytes = 0;
			let failure: Error | undefined;
			let stopping: Promise<unknown> | undefined;
			let closed = false;
			const started = Date.now();
			function stop(error: Error) {
				failure ??= error;
				stopping ??= execFileAsync('/usr/bin/systemctl', ['--user', 'stop', unit], {
					timeout: 5000,
					maxBuffer: 64 * 1024
				}).catch(async (error: { stderr?: string }) => {
					// --collect may already have removed a finished service. Only accept
					// this after the client exits, avoiding the race before unit creation.
					if (closed && /not loaded|not found/.test(error.stderr ?? '')) return;
					// If the bus disappears, the service's independent runtime limit still
					// applies. Keep the admission slot until that deadline has elapsed.
					await new Promise((done) =>
						setTimeout(done, Math.max(0, limits.wallTimeMs + 6000 - (Date.now() - started)))
					);
					child.kill('SIGKILL');
				});
			}
			const onAbort = () => stop(new Error('Lean submission cancelled'));
			signal?.addEventListener('abort', onAbort, { once: true });
			// Includes service startup; systemd enforces the runtime even if this app dies.
			const timer = setTimeout(
				() => stop(new Error('Lean submission timed out')),
				limits.wallTimeMs
			);
			function collect(chunks: Buffer[], chunk: Buffer) {
				bytes += chunk.length;
				if (bytes > limits.maxResponseBytes)
					stop(new Error('Lean worker output exceeded the limit'));
				else chunks.push(chunk);
			}
			child.stdout.on('data', (chunk: Buffer) => collect(stdout, chunk));
			child.stderr.on('data', (chunk: Buffer) => collect(stderr, chunk));
			child.on('error', (error) => {
				failure ??= error;
			});
			child.stdin.on('error', (error: NodeJS.ErrnoException) => {
				if (error.code !== 'EPIPE') stop(error);
			});
			child.on('close', async (code) => {
				closed = true;
				clearTimeout(timer);
				signal?.removeEventListener('abort', onAbort);
				// A failed systemd client can leave its service running (e.g. bus loss).
				if (code !== 0 && child.pid) {
					stop(
						new Error(
							`Lean resource worker failed (${code}): ${Buffer.concat(stderr).toString('utf8')}`
						)
					);
				}
				await stopping;
				if (failure) return reject(failure);
				if (code !== 0)
					return reject(
						new Error(
							`Lean resource worker failed (${code}): ${Buffer.concat(stderr).toString('utf8')}`
						)
					);
				try {
					const response = JSON.parse(Buffer.concat(stdout).toString('utf8'));
					if (!response.ok) throw new Error(response.error ?? 'Lean worker failed');
					resolveResult(response.result);
				} catch (error) {
					reject(error);
				}
			});
			child.stdin.end(input);
		});
	});
}
