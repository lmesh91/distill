import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isHttpError, isRedirect, type RequestEvent } from '@sveltejs/kit';
import { handleAdmin } from './admin.ts';
import { isAdmin, requireAdmin } from './roles.ts';

function locals(userId: string | null, sessionClaims: unknown = null): App.Locals {
	return { auth: () => ({ userId, sessionClaims }) } as App.Locals;
}

function request(
	path: string,
	auth: App.Locals,
	method = 'GET',
	routeId: string | null = path
): RequestEvent {
	const url = new URL(path, 'https://distill.example');
	const originalRequest = new Request(url, { method });
	const isDataRequest = url.pathname.endsWith('/__data.json');
	// SvelteKit removes the data suffix before passing the URL to server hooks.
	if (isDataRequest) url.pathname = url.pathname.slice(0, -'/__data.json'.length);
	return {
		url,
		request: originalRequest,
		route: { id: routeId },
		locals: auth,
		isDataRequest
	} as RequestEvent;
}

const admin = locals('admin-user', { metadata: { role: 'admin' } });
const denied = [
	{ auth: locals(null), status: 401 },
	{ auth: locals(null, { metadata: { role: 'admin' } }), status: 401 },
	{ auth: locals('learner'), status: 403 },
	{ auth: locals('learner', {}), status: 403 },
	{ auth: locals('learner', { metadata: null }), status: 403 },
	{ auth: locals('learner', { metadata: { role: 'user' } }), status: 403 },
	{ auth: locals('learner', { metadata: { role: 'Admin' } }), status: 403 },
	{ auth: locals('learner', { metadata: { role: ['admin'] } }), status: 403 },
	{ auth: locals('learner', { role: 'admin', publicMetadata: { role: 'admin' } }), status: 403 }
];

test('only the exact administrator claim on an authenticated session grants access', () => {
	assert.equal(isAdmin(undefined), false);
	assert.equal(isAdmin(null), false);
	assert.equal(isAdmin({ metadata: { role: 'admin' } }), true);
	assert.equal(requireAdmin(admin), 'admin-user');
	for (const { auth, status } of denied) {
		assert.throws(
			() => requireAdmin(auth),
			(error) => isHttpError(error, status)
		);
	}
});

const protectedPages: [path: string, routeId: string | null][] = [
	['/admin', '/admin'],
	['/admin/', '/admin'],
	['/admin/levels/new', '/admin/levels/new'],
	['/admin/levels/123?/save', '/admin/levels/[id]'],
	['/admin/__data.json', '/admin'],
	['/admin/levels/123/__data.json', '/admin/levels/[id]'],
	['/%61dmin/levels', '/admin/levels'],
	['/admin/levels', '/(authenticated)/admin/(editor)/levels'],
	['/distill/admin', '/admin'],
	['/management', '/admin'],
	['/admin/not-found', null],
	['/admin/levels?search=a%26b&page=2&redirect_url=https://evil.example', '/admin/levels'],
	['/admin/levels/123/__data.json?page=2', '/admin/levels/[id]']
];
const protectedApis: [path: string, routeId: string | null][] = [
	['/api/admin', '/api/admin'],
	['/api/admin/', '/api/admin'],
	['/api/admin/users/123/progress', '/api/admin/users/[id]/progress'],
	['/api/admin/levels?role=admin', '/api/admin/levels'],
	['/api/%61dmin/levels', '/api/admin/levels'],
	['/api/admin/levels', '/api/(private)/admin/levels'],
	['/management-api', '/api/admin'],
	['/api/admin/not-found', null]
];
const protectedRoutes = [...protectedPages, ...protectedApis];

test('denied page, data, and action requests redirect signed-out users and forbid non-admins', async () => {
	for (const [path, routeId] of protectedPages) {
		for (const method of ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']) {
			for (const { auth, status } of denied) {
				const event = request(path, auth, method, routeId);
				await assert.rejects(
					async () =>
						handleAdmin({
							event,
							resolve: async () => assert.fail('Protected handler must not run')
						}),
					(error) => {
						if (status === 403) return isHttpError(error, 403);
						assert.ok(isRedirect(error));
						assert.equal(error.status, 303);
						const location = new URL(error.location, event.url.origin);
						assert.equal(location.origin, event.url.origin);
						assert.equal(location.pathname, '/sign-in');
						assert.equal(
							location.searchParams.get('redirect_url'),
							event.url.pathname + event.url.search
						);
						return true;
					},
					`${method} ${path} should ${status === 401 ? 'redirect to sign-in' : 'return 403'}`
				);
			}
		}
	}
});

test('denied API requests return JSON errors without redirecting or running handlers', async () => {
	for (const [path, routeId] of protectedApis) {
		for (const method of ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']) {
			for (const { auth, status } of denied) {
				const event = request(path, auth, method, routeId);
				event.request.headers.set('accept', 'text/html');
				const response = await handleAdmin({
					event,
					resolve: async () => assert.fail('Protected handler must not run')
				});
				assert.equal(response.status, status);
				assert.equal(response.headers.get('content-type'), 'application/json');
				assert.equal(response.headers.get('location'), null);
				assert.deepEqual(await response.json(), {
					error: status === 401 ? 'Unauthorized' : 'Forbidden'
				});
			}
		}
	}
});

test('administrators can reach page loads, actions, and every API method', async () => {
	for (const [path, routeId] of protectedRoutes) {
		for (const method of ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']) {
			const event = request(path, admin, method, routeId);
			const response = new Response(null, { status: 204 });
			let calls = 0;
			const result = await handleAdmin({
				event,
				resolve: async (resolvedEvent) => {
					assert.equal(resolvedEvent, event);
					calls++;
					return response;
				}
			});
			assert.equal(calls, 1);
			assert.equal(result, response);
		}
	}
});

test('public, authentication, webhook, and learner routes retain their own access rules', async () => {
	for (const path of [
		'/',
		'/sign-in',
		'/sign-up',
		'/health',
		'/app',
		'/app/levels/example',
		'/api/submissions',
		'/api/levels/123/progress',
		'/api/webhooks/clerk',
		'/administrator',
		'/api/administer',
		'/app?redirect_url=/admin'
	]) {
		const response = new Response('Handled by the route');
		assert.equal(
			await handleAdmin({
				event: request(path, {
					auth: () => assert.fail('Unrelated routes must not require an administrator')
				}),
				resolve: async () => response
			}),
			response
		);
	}
});
