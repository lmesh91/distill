import type { LevelType } from '$lib/types/level';

/**
 * validation for the administrator level-creation form (#40). it runs on the server before a
 * level is saved and has no server-only imports, so the page can reuse `slugify`
 */

export const levelTypes: { value: LevelType; label: string }[] = [
	{ value: 'guided', label: 'Guided (match an English proof)' },
	{ value: 'hints', label: 'Hints' },
	{ value: 'from-scratch', label: 'From scratch' }
];

/** a new level as the form describes it, before database ids and timestamps */
export interface NewLevelInput {
	title: string;
	slug: string;
	description: string;
	type: LevelType;
	statement: string;
	starterCode: string;
	lockedLines: number[];
	expectedGoal?: string;
	targetProof?: string;
	hints: string[];
	verification: { theoremName: string; challengeSource: string };
	/** hex id of the parent level, or undefined for a root level */
	parentId?: string;
	order: number;
	published: boolean;
}

export type LevelFormField =
	| 'title'
	| 'slug'
	| 'description'
	| 'type'
	| 'statement'
	| 'starterCode'
	| 'lockedLines'
	| 'expectedGoal'
	| 'targetProof'
	| 'hints'
	| 'theoremName'
	| 'challengeSource'
	| 'parentId'
	| 'order';

/** the raw text of every field, so a rejected form can be shown again as the admin left it */
export type LevelFormValues = Record<LevelFormField, string> & { published: boolean };

export type LevelFormResult =
	| { ok: true; level: NewLevelInput }
	| { ok: false; errors: Partial<Record<LevelFormField, string>>; values: LevelFormValues };

/** lowercase words joined by - or _, like the existing `subset_rfl` and `hello-world` */
export const slugPattern = /^[a-z0-9]+(?:[-_][a-z0-9]+)*$/;

/** a slug suggestion from a title: "Subset is reflexive!" becomes "subset-is-reflexive" */
export function slugify(title: string): string {
	return title
		.normalize('NFKD')
		.replace(/[̀-ͯ]/g, '')
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, '-')
		.replace(/^-+|-+$/g, '')
		.slice(0, 60)
		.replace(/-+$/, '');
}

// fully qualified Lean names like `Exercise.hello_world`
const theoremNamePattern = /^[\p{L}_][\p{L}\p{N}_'!?]*(?:\.[\p{L}_][\p{L}\p{N}_'!?]*)*$/u;

const text = (form: FormData, key: string) => {
	const value = form.get(key);
	return typeof value === 'string' ? value : '';
};

// textareas send \r\n; levels store \n like the rest of the code
const normalize = (value: string) => value.replace(/\r\n?/g, '\n');

/** reads and checks the submitted form; every problem is reported at once, per field */
export function parseLevelForm(form: FormData): LevelFormResult {
	const values: LevelFormValues = {
		title: text(form, 'title').trim(),
		slug: text(form, 'slug').trim(),
		description: normalize(text(form, 'description')).trim(),
		type: text(form, 'type'),
		statement: normalize(text(form, 'statement')).trim(),
		starterCode: normalize(text(form, 'starterCode')).replace(/\s+$/, ''),
		lockedLines: text(form, 'lockedLines').trim(),
		expectedGoal: normalize(text(form, 'expectedGoal')).trim(),
		targetProof: normalize(text(form, 'targetProof')).trim(),
		hints: normalize(text(form, 'hints')),
		theoremName: text(form, 'theoremName').trim(),
		challengeSource: normalize(text(form, 'challengeSource')).replace(/\s+$/, ''),
		parentId: text(form, 'parentId').trim(),
		order: text(form, 'order').trim(),
		published: form.get('published') === 'on'
	};
	const errors: Partial<Record<LevelFormField, string>> = {};
	const required: [LevelFormField, string][] = [
		['title', 'Give the level a title.'],
		['description', 'Add a description so learners know what to do.'],
		['statement', 'Add the statement learners will prove.'],
		['starterCode', 'Add the starter code learners begin with.'],
		['theoremName', 'Add the theorem name used to check submissions.'],
		['challengeSource', 'Add the Lean module submissions are checked against.']
	];
	for (const [field, message] of required) if (!values[field]) errors[field] = message;

	if (values.title.length > 120) errors.title = 'Keep the title under 120 characters.';

	if (!values.slug) errors.slug = 'Add a slug for the level’s address.';
	else if (!slugPattern.test(values.slug))
		errors.slug = 'Use lowercase letters and numbers, separated by - or _.';

	const type = levelTypes.find((option) => option.value === values.type)?.value;
	if (!type) errors.type = 'Pick a level type.';
	if (type === 'guided' && !values.targetProof)
		errors.targetProof = 'Guided levels need the English proof learners match.';

	if (values.theoremName && !theoremNamePattern.test(values.theoremName))
		errors.theoremName = 'Use a Lean name like hello_world or Exercise.hello_world.';
	else if (values.theoremName && values.challengeSource) {
		// the last part is enough: the challenge may open a namespace around the theorem
		const short = values.theoremName.split('.').at(-1)!;
		const declares = new RegExp(
			String.raw`\b(?:theorem|lemma)\s+(?:\S*\.)?${escape(short)}\b`,
			'u'
		);
		if (!declares.test(values.challengeSource))
			errors.challengeSource = `The challenge must declare the theorem ${values.theoremName}.`;
	}

	const starterLineCount = values.starterCode ? values.starterCode.split('\n').length : 0;
	let lockedLines: number[] = [];
	// with no starter code yet, its own error says so; line numbers are checked once it's there
	if (values.lockedLines && values.starterCode) {
		const parts = values.lockedLines.split(/[\s,]+/).filter(Boolean);
		const numbers = parts.map(Number);
		if (numbers.some((n) => !Number.isInteger(n) || n < 1))
			errors.lockedLines = 'List line numbers like 1, 2.';
		else if (numbers.some((n) => n > starterLineCount))
			errors.lockedLines = `The starter code only has ${starterLineCount} lines.`;
		else lockedLines = [...new Set(numbers)].sort((a, b) => a - b);
	}

	if (values.parentId && !/^[0-9a-f]{24}$/.test(values.parentId))
		errors.parentId = 'Pick a parent level from the list.';

	const order = values.order === '' ? 0 : Number(values.order);
	if (!Number.isInteger(order) || order < 0) errors.order = 'Use a whole number, 0 or more.';

	if (Object.keys(errors).length > 0 || !type) return { ok: false, errors, values };

	return {
		ok: true,
		level: {
			title: values.title,
			slug: values.slug,
			description: values.description,
			type,
			statement: values.statement,
			starterCode: values.starterCode,
			lockedLines,
			expectedGoal: values.expectedGoal || undefined,
			targetProof: values.targetProof || undefined,
			// one hint per line; blank lines are dropped
			hints: values.hints
				.split('\n')
				.map((hint) => hint.trim())
				.filter(Boolean),
			verification: {
				theoremName: values.theoremName,
				challengeSource: values.challengeSource
			},
			parentId: values.parentId || undefined,
			order,
			published: values.published
		}
	};
}

function escape(value: string) {
	return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
