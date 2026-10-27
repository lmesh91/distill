// Separate build entrypoint: this trusted orchestrator runs inside the resource unit.
import { readFile, statfs } from 'node:fs/promises';
import { join } from 'node:path';
import { compileLean } from './leanRuntime.ts';
import { verifyLean } from './verificationRuntime.ts';
import type { LeanLimits } from './leanLimits.ts';

/** User managers can accept properties without delegated controllers. Fail closed. */
async function checkLimits(limits: LeanLimits) {
	const membership = await readFile('/proc/self/cgroup', 'utf8');
	const group = membership
		.split('\n')
		.find((line) => line.startsWith('0::'))
		?.slice(3);
	if (!group) throw new Error('Lean requires cgroup v2');
	const root = join('/sys/fs/cgroup', group);
	const read = async (name: string) => (await readFile(join(root, name), 'utf8')).trim();
	const [memory, swap, tasks, cpu, scratch] = await Promise.all([
		read('memory.max'),
		read('memory.swap.max'),
		read('pids.max'),
		read('cpu.max'),
		statfs('/tmp')
	]);
	const [quota, period] = cpu.split(' ').map(Number);
	if (
		!(Number(memory) <= limits.memoryBytes) ||
		swap !== '0' ||
		!(Number(tasks) <= limits.tasks) ||
		!(quota / period <= limits.cpuPercent / 100) ||
		scratch.type !== 0x01021994 ||
		scratch.blocks * scratch.bsize > limits.scratchBytes ||
		scratch.files > limits.scratchInodes
	) {
		throw new Error('Lean resource limits are not enforced by this host');
	}
	return root;
}

try {
	const cgroup = await checkLimits(JSON.parse(process.argv[2]));
	const chunks: Buffer[] = [];
	let bytes = 0;
	for await (const chunk of process.stdin) {
		bytes += chunk.length;
		if (bytes > 1024 * 1024) throw new Error('Lean worker input exceeded the limit');
		chunks.push(chunk);
	}
	const job = JSON.parse(Buffer.concat(chunks).toString('utf8'));
	const outcome = await (
		job.kind === 'compile' ? compileLean(job.source) : verifyLean(job.source, job.target)
	).then(
		(result) => ({ result }),
		(error: unknown) => ({ error })
	);
	// Lean may abort while creating a thread rather than report a diagnostic.
	// Read the kernel counter to distinguish a task quota from a compiler error.
	const events = await readFile(join(cgroup, 'pids.events'), 'utf8');
	if (/^max [1-9]\d*$/m.test(events)) throw new Error('Lean process limit exceeded');
	if ('error' in outcome) throw outcome.error;
	process.stdout.write(JSON.stringify({ ok: true, result: outcome.result }));
} catch (error) {
	process.stdout.write(
		JSON.stringify({
			ok: false,
			error: error instanceof Error ? error.message : 'Lean worker failed'
		})
	);
}
