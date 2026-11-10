/**
 * Finds where a level's locked starter lines are in the code the editor opens with.
 *
 * `lockedLines` are 1-based line numbers in `starterCode`. Saved code may have extra or missing
 * lines, so the whole starter is aligned with the code (longest common subsequence of lines) and
 * each locked line follows its aligned position, which keeps repeated lines such as blanks apart.
 * A locked line with no match is dropped. Returns 1-based line numbers in `code`.
 */
export function findLockedLines(
	starterCode: string,
	lockedLines: number[],
	code: string
): number[] {
	const starter = starterCode.split('\n');
	const wanted = [...new Set(lockedLines)]
		.filter((line) => line >= 1 && line <= starter.length)
		.sort((a, b) => a - b);
	if (code === starterCode) return wanted;

	const lines = code.split('\n');
	// common[i][j]: length of the longest common subsequence of starter[i..] and lines[j..]
	const common = Array.from({ length: starter.length + 1 }, () =>
		new Array<number>(lines.length + 1).fill(0)
	);
	for (let i = starter.length - 1; i >= 0; i--) {
		for (let j = lines.length - 1; j >= 0; j--) {
			common[i][j] =
				starter[i] === lines[j]
					? common[i + 1][j + 1] + 1
					: Math.max(common[i + 1][j], common[i][j + 1]);
		}
	}
	const match = new Map<number, number>();
	for (let i = 0, j = 0; i < starter.length && j < lines.length; ) {
		if (starter[i] === lines[j]) match.set(i++ + 1, j++ + 1);
		else if (common[i + 1][j] >= common[i][j + 1]) i++;
		else j++;
	}
	return wanted.flatMap((line) => match.get(line) ?? []);
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
 * Whether a change to `doc` leaves every locked line intact. Whole lines may still be added or
 * removed directly before or after a locked line, but its text can't change and it can't be merged
 * with a neighbour.
 */
export function changeKeepsLines(change: Change, locked: LineRange[], doc: string): boolean {
	// after the change, is the text just before `change.from` / after `change.to` a line break?
	const breakBefore =
		change.inserted === ''
			? change.from === 0 || doc[change.from - 1] === '\n'
			: change.inserted.endsWith('\n');
	const breakAfter =
		change.inserted === ''
			? change.to === doc.length || doc[change.to] === '\n'
			: change.inserted.startsWith('\n');
	return locked.every(({ from, to }) => {
		if (change.to < from || change.from > to) return true;
		if (change.to === from && change.from < from) return breakBefore;
		if (change.from === to && change.to > to) return breakAfter;
		if (change.from !== change.to) return false;
		if (change.from === to && change.inserted.startsWith('\n')) return true;
		return change.from === from && change.inserted.endsWith('\n');
	});
}
