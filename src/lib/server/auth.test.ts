import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isRedirect, type RequestEvent } from '@sveltejs/kit';
import { protectRoutes } from './auth.ts';
import { load } from '../../routes/app/+layout.server.ts';

function request(path: string, userId: string | null = null, method = 'GET') {
	const url = new URL(path, 'https://distill.example');
	return {
		url,
		request: new Request(url, { method }),
		route: { id: url.pathname.replace(/\/$/, '') || '/' },
		locals: { auth: () => ({ userId }) },
		isDataRequest: false
	} as RequestEvent;
}

function denyResolve(): never {
	assert.fail('An unauthenticated request must not reach the database or route handler');
}

async function expectSignIn(event: RequestEvent) {
	await assert.rejects(
		async () => protectRoutes({ event, resolve: denyResolve }),
		(error: unknown) => {
			assert.ok(isRedirect(error));
			assert.equal(error.status, 303);
			const target = new URL(error.location, event.url);
			assert.equal(target.pathname, '/sign-in');
			assert.equal(target.searchParams.get('redirect_url'), event.url.href);
			return true;
		}
	);
}

test('signed-out app requests redirect before resolving, preserving the destination', async () => {
	for (const path of [
		'/app',
		'/app/',
		'/app/lean',
		'/app/levels/first-proof?mode=guided&next=%2Fapp%2Flean',
		'/app/future/nested-page'
	]) {
		await expectSignIn(request(path));
	}
	await expectSignIn(request('/app/levels/first-proof?/save', null, 'POST'));
});

test('data navigation, encoded paths, and route groups cannot bypass the guard', async () => {
	const data = request('/app/lean');
	data.isDataRequest = true;
	await expectSignIn(data);
	const encoded = request('/%61pp/lean');
	encoded.route.id = '/app/lean';
	await expectSignIn(encoded);
	const grouped = request('/app/lean');
	grouped.route.id = '/(account)/app/(tools)/lean' as typeof grouped.route.id;
	await expectSignIn(grouped);
});

test('account APIs return JSON 401 without a redirect or downstream work', async () => {
	for (const [method, path] of [
		['GET', '/api/whoami'],
		['POST', '/api/submissions'],
		['PUT', '/api/levels/abc/progress'],
		['DELETE', '/api/future/resource'],
		['POST', '/api/webhooks/clerk/other']
	]) {
		const response = await protectRoutes({
			event: request(path, null, method),
			resolve: denyResolve
		});
		assert.equal(response.status, 401);
		assert.equal(response.headers.get('location'), null);
		assert.match(response.headers.get('content-type') ?? '', /application\/json/);
		assert.deepEqual(await response.json(), { error: 'Unauthorized' });
	}
});

test('public pages, auth flows, health, and the signed webhook remain reachable', async () => {
	for (const path of [
		'/',
		'/sign-in',
		'/sign-in/factor-one',
		'/sign-up/verify-email-address',
		'/health',
		'/api/webhooks/clerk',
		'/api/webhooks/clerk/',
		'/application',
		'/apiary'
	]) {
		const event = request(path, null, path.includes('/webhooks/') ? 'POST' : 'GET');
		const response = new Response('public');
		assert.equal(
			await protectRoutes({
				event,
				resolve: async (received) => {
					assert.equal(received, event);
					return response;
				}
			}),
			response
		);
	}
});

test('authenticated requests resolve, but an expired session is checked again', async () => {
	let databaseCalls = 0;
	const response = new Response('private');
	const resolve = async () => {
		databaseCalls += 1;
		return response;
	};
	for (const path of ['/app', '/app/lean', '/app/levels/first-proof', '/api/whoami']) {
		assert.equal(await protectRoutes({ event: request(path, 'user_test'), resolve }), response);
	}
	assert.equal(databaseCalls, 4);
	await assert.rejects(
		async () => protectRoutes({ event: request('/app/lean'), resolve }),
		isRedirect
	);
	assert.equal(databaseCalls, 4);
});

test('the app layout tracks the URL so client navigation rechecks authentication', async () => {
	const event = request('/app/lean', 'user_test');
	let tracksUrl = false;
	const href = event.url.href;
	Object.defineProperty(event.url, 'href', {
		get() {
			tracksUrl = true;
			return href;
		}
	});
	assert.deepEqual(await load(event as Parameters<typeof load>[0]), { userId: 'user_test' });
	assert.equal(tracksUrl, true);
});
