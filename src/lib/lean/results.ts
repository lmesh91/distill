import type { Diagnostic } from '$lib/lean/client';

export type ResultTone = 'pending' | 'success' | 'warning' | 'error' | 'offline';

export interface LeanResultItem {
	severity: 'error' | 'warning' | 'info';
	label: string;
	// 0-based, as Lean reports it
	line: number;
	character: number;
	message: string;
}

export interface LeanResults {
	tone: ResultTone;
	headline: string;
	errors: number;
	warnings: number;
	items: LeanResultItem[];
}

// LSP severities: 1 error, 2 warning, 3 information, 4 hint
const severityOrder = { error: 0, warning: 1, info: 2 } as const;

function severityOf(diagnostic: Diagnostic): LeanResultItem['severity'] {
	if (diagnostic.severity === 1) return 'error';
	if (diagnostic.severity === 2) return 'warning';
	return 'info';
}

function plural(count: number, word: string) {
	return `${count} ${word}${count === 1 ? '' : 's'}`;
}

/**
 * turns the editor's connection status and Lean's diagnostics into what the results panel shows:
 * a one-line headline and the problems sorted by line, then by severity
 */
export function summarizeLeanResults(status: string, diagnostics: Diagnostic[]): LeanResults {
	const items = diagnostics
		.map((diagnostic) => {
			const severity = severityOf(diagnostic);
			return {
				severity,
				label: severity === 'error' ? 'Error' : severity === 'warning' ? 'Warning' : 'Info',
				line: diagnostic.range.start.line,
				character: diagnostic.range.start.character,
				message: diagnostic.message.trim()
			};
		})
		.sort(
			(a, b) =>
				a.line - b.line ||
				severityOrder[a.severity] - severityOrder[b.severity] ||
				a.character - b.character
		);

	const errors = items.filter((item) => item.severity === 'error').length;
	const warnings = items.filter((item) => item.severity === 'warning').length;
	const counts = { errors, warnings, items };

	if (
		status.startsWith('Disconnected') ||
		status.startsWith('Unable') ||
		status.includes('failed')
	) {
		return { ...counts, tone: 'offline', headline: status };
	}
	if (status.startsWith('Connecting')) {
		return { ...counts, tone: 'pending', headline: 'Connecting to Lean…' };
	}
	if (status !== 'Done') {
		return { ...counts, tone: 'pending', headline: 'Checking your proof…' };
	}
	if (errors > 0) {
		const parts = [plural(errors, 'error'), ...(warnings > 0 ? [plural(warnings, 'warning')] : [])];
		return { ...counts, tone: 'error', headline: parts.join(', ') };
	}
	if (warnings > 0) {
		const usesSorry = items.some((item) => /declaration uses ['`]sorry['`]/.test(item.message));
		return {
			...counts,
			tone: 'warning',
			headline: usesSorry
				? `${plural(warnings, 'warning')}: the proof still has a sorry`
				: plural(warnings, 'warning')
		};
	}
	return { ...counts, tone: 'success', headline: 'No errors or warnings' };
}
