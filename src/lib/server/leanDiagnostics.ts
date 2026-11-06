import type { LeanDiagnostic } from '../types/submission.ts';

function position(value: unknown): LeanDiagnostic['position'] {
	if (!value || typeof value !== 'object') return undefined;
	const pos = value as Record<string, unknown>;
	return typeof pos.line === 'number' && typeof pos.column === 'number'
		? { line: pos.line, column: pos.column }
		: undefined;
}

/** Parse Lean's NDJSON diagnostics, retaining arbitrary #eval output separately. */
export function parseLeanDiagnostics(stdout: string): LeanDiagnostic[] {
	const diagnostics: LeanDiagnostic[] = [];
	for (const line of stdout.split('\n')) {
		let value;
		try {
			value = JSON.parse(line);
		} catch {
			// #eval IO.print need not end with a newline. Lean's diagnostic can then
			// follow arbitrary text on the same line; never let that hide a warning.
			const start = line.lastIndexOf('{"caption":');
			if (start >= 0) {
				try {
					value = JSON.parse(line.slice(start));
				} catch {
					/* Reject malformed JSON-like output below. */
				}
			}
			if (!value && line.includes('{')) {
				diagnostics.push({
					severity: 'error',
					message: 'Could not read Lean diagnostics from compiler output.'
				});
			}
		}
		if (!value || typeof value !== 'object' || typeof value.data !== 'string') continue;
		if (!['error', 'warning', 'information'].includes(value.severity)) continue;
		diagnostics.push({
			severity: value.severity,
			message: value.data,
			...(typeof value.fileName === 'string' ? { fileName: value.fileName } : {}),
			...(position(value.pos) ? { position: position(value.pos) } : {}),
			...(position(value.endPos) ? { endPosition: position(value.endPos) } : {})
		});
	}
	return diagnostics;
}
