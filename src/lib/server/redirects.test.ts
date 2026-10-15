import assert from 'node:assert/strict';
import { test } from 'node:test';
import { safeRedirectPath } from './redirects.ts';

const origin = 'http://localhost:5173';

test('uses the fallback when there is no target', () => {
	assert.equal(safeRedirectPath(null, origin, '/app'), '/app');
	assert.equal(safeRedirectPath('', origin, '/app'), '/app');
});

test('keeps same-site paths and full URLs, including query and hash', () => {
	assert.equal(safeRedirectPath('/app/lean', origin, '/app'), '/app/lean');
	assert.equal(safeRedirectPath(`${origin}/app?x=1#top`, origin, '/app'), '/app?x=1#top');
});

test('rejects other sites', () => {
	assert.equal(safeRedirectPath('https://evil.example/app', origin, '/app'), '/app');
	assert.equal(safeRedirectPath('//evil.example/app', origin, '/app'), '/app');
	assert.equal(safeRedirectPath('javascript:alert(1)', origin, '/app'), '/app');
});
