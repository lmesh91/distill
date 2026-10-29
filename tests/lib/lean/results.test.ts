import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Diagnostic } from '../../../src/lib/lean/client.ts';
import { summarizeLeanResults } from '../../../src/lib/lean/results.ts';

function diagnostic(
	severity: number,
	line: number,
	character: number,
	message: string
): Diagnostic {
	return { severity, message, range: { start: { line, character } } };
}

test('a finished check with no problems is a success', () => {
	assert.deepEqual(summarizeLeanResults('Done', []), {
		tone: 'success',
		headline: 'No errors or warnings',
		errors: 0,
		warnings: 0,
		items: []
	});
});

test('connecting and checking are pending, even if old results are still listed', () => {
	assert.equal(summarizeLeanResults('Connecting…', []).headline, 'Connecting to Lean…');
	const checking = summarizeLeanResults('Checking…', [diagnostic(1, 0, 0, 'old')]);
	assert.equal(checking.tone, 'pending');
	assert.equal(checking.headline, 'Checking your proof…');
});

test('lost connections show the editor status as an offline problem', () => {
	const results = summarizeLeanResults('Disconnected. Is the relay running?', []);
	assert.equal(results.tone, 'offline');
	assert.equal(results.headline, 'Disconnected. Is the relay running?');
	assert.equal(summarizeLeanResults('Lean initialization failed: boom', []).tone, 'offline');
});

test('errors are counted and listed by line, then severity, with 0-based positions kept', () => {
	const results = summarizeLeanResults('Done', [
		diagnostic(2, 4, 2, "declaration uses 'sorry'"),
		diagnostic(1, 4, 10, '  unsolved goals\n⊢ q  '),
		diagnostic(1, 1, 0, 'Type mismatch'),
		diagnostic(3, 0, 0, 'info: checked')
	]);
	assert.equal(results.tone, 'error');
	assert.equal(results.headline, '2 errors, 1 warning');
	assert.deepEqual(
		results.items.map((item) => [item.label, item.line, item.character]),
		[
			['Info', 0, 0],
			['Error', 1, 0],
			['Error', 4, 10],
			['Warning', 4, 2]
		]
	);
	assert.equal(results.items[2].message, 'unsolved goals\n⊢ q');
});

test('a proof that only has warnings is flagged, and a sorry is called out', () => {
	const sorry = summarizeLeanResults('Done', [diagnostic(2, 1, 0, 'declaration uses `sorry`')]);
	assert.equal(sorry.tone, 'warning');
	assert.equal(sorry.headline, '1 warning: the proof still has a sorry');

	const other = summarizeLeanResults('Done', [
		diagnostic(2, 1, 0, 'unused variable `h`'),
		diagnostic(2, 2, 0, 'unused variable `k`')
	]);
	assert.equal(other.headline, '2 warnings');
});
