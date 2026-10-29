/**
 * Finds where a level's locked starter lines are in the code the editor opens with.
 *
 * `lockedLines` are 1-based line numbers in `starterCode`. Saved code may have extra lines, so
 * each locked line is matched by its text, in order, and dropped if the user's code lost it.
 * Returns 1-based line numbers in `code`.
 */
export function findLockedLines(
	starterCode: string,
	lockedLines: number[],
	code: string
): number[] {
	const starter = starterCode.split('\n');
	const lines = code.split('\n');
	const found: number[] = [];
	let next = 0;
	for (const lineNumber of [...lockedLines].sort((a, b) => a - b)) {
		const text = starter[lineNumber - 1];
		if (text === undefined) continue;
		const index = lines.indexOf(text, next);
		if (index === -1) continue;
		found.push(index + 1);
		next = index + 1;
	}
	return found;
}

/**
 * Where a caret that landed on a locked line should go instead: the nearest unlocked line in the
 * direction it was moving (`1` is down), or the other way if that runs out. `atEnd` means the caret
 * goes to the end of that line, since it came from below. `null` if every line is locked.
 */
export function nearestFreeLine(
	line: number,
	direction: 1 | -1,
	lineCount: number,
	locked: Set<number>
): { line: number; atEnd: boolean } | null {
	if (!locked.has(line)) return { line, atEnd: false };
	for (const step of [direction, -direction]) {
		let next = line;
		while (locked.has(next)) next += step;
		if (next >= 1 && next <= lineCount) return { line: next, atEnd: step < 0 };
	}
	return null;
}

/** a locked line's start and end offsets in the document, excluding its newline */
export type LineRange = { from: number; to: number };

/** a change to the document, with offsets in the document before the change */
export type Change = { from: number; to: number; inserted: string };

/**
 * Whether a change leaves every locked line intact. New lines may still be added directly before
 * or after a locked line, but its text can't change and it can't be merged with a neighbour.
 */
export function changeKeepsLines(change: Change, locked: LineRange[]): boolean {
	return locked.every(({ from, to }) => {
		if (change.from === change.to) {
			if (change.from < from || change.from > to) return true;
			if (change.from === to && change.inserted.startsWith('\n')) return true;
			return change.from === from && change.inserted.endsWith('\n');
		}
		return change.to < from || change.from > to;
	});
}
