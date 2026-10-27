import { runLeanJob } from './leanJobs.ts';
export type { CompilationResult } from './leanRuntime.ts';

/** Compile inside the same resource boundary used by full proof verification. */
export function compileLean(source: string, signal?: AbortSignal) {
	return runLeanJob({ kind: 'compile', source }, { signal });
}
