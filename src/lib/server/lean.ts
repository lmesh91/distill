import { spawn } from 'node:child_process';
import { leanSandboxArgs } from './leanSandbox.ts';

export interface CompilationResult {
	compiled: boolean;
	exitCode: number;
	stdout: string;
	stderr: string;
}

// Basic process guards; comprehensive resource quotas are tracked in #77.
const timeoutMs = 30_000;
const maxOutputBytes = 1024 * 1024;

/** Run a fresh batch compiler, independently of the editor's language server. */
export async function compileLean(source: string): Promise<CompilationResult> {
	const args = await leanSandboxArgs();
	return new Promise((resolveResult, reject) => {
		const compiler = spawn('bwrap', args, {
			cwd: '/',
			// Also keep secrets out of Bubblewrap itself (including its /proc environment).
			env: { PATH: process.env.PATH },
			stdio: ['pipe', 'pipe', 'pipe'],
			detached: true
		});
		const stdout: Buffer[] = [];
		const stderr: Buffer[] = [];
		let outputBytes = 0;
		let failure: Error | undefined;

		function stop(error: Error) {
			failure ??= error;
			if (compiler.pid) {
				try {
					// Kill the supervisor too: its PID namespace tears down every descendant,
					// including children that create their own process group/session.
					process.kill(-compiler.pid, 'SIGKILL');
				} catch (error) {
					if ((error as NodeJS.ErrnoException).code !== 'ESRCH') compiler.kill('SIGKILL');
				}
			}
		}

		const timer = setTimeout(() => stop(new Error('Lean compilation timed out')), timeoutMs);
		function collect(chunks: Buffer[], chunk: Buffer) {
			outputBytes += chunk.length;
			if (outputBytes > maxOutputBytes) {
				stop(new Error('Lean compiler output exceeded the limit'));
			} else {
				chunks.push(chunk);
			}
		}
		compiler.stdout.on('data', (chunk: Buffer) => collect(stdout, chunk));
		compiler.stderr.on('data', (chunk: Buffer) => collect(stderr, chunk));
		compiler.on('error', (error) => {
			failure ??= error;
		});
		compiler.stdin.on('error', (error: NodeJS.ErrnoException) => {
			// A compiler can exit before consuming all input; its exit code remains authoritative.
			if (error.code !== 'EPIPE') stop(error);
		});
		compiler.on('close', (exitCode, signal) => {
			clearTimeout(timer);
			const errorOutput = Buffer.concat(stderr).toString('utf8');
			if (failure) reject(failure);
			else if (exitCode === null) reject(new Error(`Lean compiler terminated (${signal})`));
			else if (/^bwrap:/m.test(errorOutput))
				reject(new Error(`Lean sandbox failed: ${errorOutput}`));
			else if (exitCode >= 128) reject(new Error(`Lean sandbox terminated (${exitCode})`));
			else
				resolveResult({
					compiled: exitCode === 0,
					exitCode,
					stdout: Buffer.concat(stdout).toString('utf8'),
					stderr: errorOutput
				});
		});
		compiler.stdin.end(source);
	});
}
