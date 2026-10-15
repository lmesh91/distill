import { spawn } from 'node:child_process';
import { resolve } from 'node:path';

export interface CompilationResult {
	compiled: boolean;
	exitCode: number;
	stdout: string;
	stderr: string;
}

// These are basic process guards; untrusted Lean still needs an OS sandbox (#76/#77).
const timeoutMs = 30_000;
const maxOutputBytes = 1024 * 1024;

/** Run a fresh batch compiler, independently of the editor's language server. */
export function compileLean(source: string): Promise<CompilationResult> {
	return new Promise((resolveResult, reject) => {
		const compiler = spawn('lake', ['env', 'lean', '--stdin'], {
			cwd: resolve(process.env.LEAN_PROJECT_DIR ?? 'lean'),
			stdio: ['pipe', 'pipe', 'pipe'],
			// Allow killing Lake and its compiler together on POSIX hosts.
			detached: process.platform !== 'win32'
		});
		const stdout: Buffer[] = [];
		const stderr: Buffer[] = [];
		let outputBytes = 0;
		let failure: Error | undefined;

		function stop(error: Error) {
			failure ??= error;
			if (compiler.pid) {
				try {
					if (process.platform === 'win32') compiler.kill('SIGKILL');
					else process.kill(-compiler.pid, 'SIGKILL');
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
			if (failure) reject(failure);
			else if (exitCode === null) reject(new Error(`Lean compiler terminated (${signal})`));
			else
				resolveResult({
					compiled: exitCode === 0,
					exitCode,
					stdout: Buffer.concat(stdout).toString('utf8'),
					stderr: Buffer.concat(stderr).toString('utf8')
				});
		});
		compiler.stdin.end(source);
	});
}
