import assert from 'node:assert/strict';
import { test } from 'node:test';
import { accountLinks, primaryLinks, visibleLinks, type NavLink } from './links.ts';

const allLinks = [...primaryLinks, ...accountLinks];

function labels(links: NavLink[]) {
	return links.map((link) => link.label);
}

function active(pathname: string, signedIn = true) {
	return labels(visibleLinks(allLinks, signedIn).filter((link) => link.isActive(pathname)));
}

test('exactly one link is highlighted on each primary page', () => {
	assert.deepEqual(active('/'), ['Home']);
	assert.deepEqual(active('/app'), ['Play']);
	assert.deepEqual(active('/app/lean'), ['Sandbox']);
});

test('no link is highlighted on pages outside the navigation', () => {
	assert.deepEqual(active('/app/levels/subset_rfl'), []);
	assert.deepEqual(active('/design'), []);
	assert.deepEqual(active('/app/leaning'), []);
});

test('the sign-in and sign-up links are highlighted on their pages, including Clerk sub-steps', () => {
	assert.deepEqual(active('/sign-in', false), ['Sign in']);
	assert.deepEqual(active('/sign-up/verify-email-address', false), ['Sign up']);
});

test('signed-out visitors see the home page and the sign-in links, not the game', () => {
	assert.deepEqual(labels(visibleLinks(primaryLinks, false)), ['Home']);
	assert.deepEqual(labels(visibleLinks(accountLinks, false)), ['Sign in', 'Sign up']);
});

test('signed-in users see the game links and no sign-in links', () => {
	assert.deepEqual(labels(visibleLinks(primaryLinks, true)), ['Home', 'Play', 'Sandbox']);
	assert.deepEqual(labels(visibleLinks(accountLinks, true)), []);
});
