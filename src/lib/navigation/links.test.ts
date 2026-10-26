import assert from 'node:assert/strict';
import { test } from 'node:test';
import { primaryLinks } from './links.ts';

function active(pathname: string) {
	return primaryLinks.filter((link) => link.isActive(pathname)).map((link) => link.label);
}

test('exactly one link is highlighted on each primary page', () => {
	assert.deepEqual(active('/'), ['Home']);
	assert.deepEqual(active('/app'), ['Play']);
	assert.deepEqual(active('/app/lean'), ['Sandbox']);
});

test('no link is highlighted on pages outside the primary navigation', () => {
	assert.deepEqual(active('/sign-in'), []);
	assert.deepEqual(active('/sign-up/verify-email-address'), []);
});
