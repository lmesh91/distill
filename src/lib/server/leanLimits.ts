/** Server policy. Submission JSON must never override these limits. */
export const leanLimits = {
	wallTimeMs: 30_000,
	memoryBytes: 1024 * 1024 * 1024,
	cpuPercent: 100,
	tasks: 64,
	scratchBytes: 128 * 1024 * 1024,
	scratchInodes: 8192,
	maxConcurrent: 4,
	maxResponseBytes: 8 * 1024 * 1024
} as const;

export type LeanLimits = { [K in keyof typeof leanLimits]: number };
