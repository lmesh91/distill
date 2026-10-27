import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isHttpError, type RequestEvent } from '@sveltejs/kit';
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
	return {
		url,
		request: new Request(url, { method }),
		route: { id: routeId },
		locals: auth,
		isDataRequest: path.includes('__data.json')
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

const protectedRoutes: [path: string, routeId: string | null][] = [
	['/admin', '/admin'],
	['/admin/', '/admin'],
	['/admin/levels/new', '/admin/levels/new'],
	['/admin/levels/123?/save', '/admin/levels/[id]'],
	['/admin/__data.json', '/admin'],
	['/admin/levels/123/__data.json', '/admin/levels/[id]'],
	['/api/admin', '/api/admin'],
	['/api/admin/', '/api/admin'],
	['/api/admin/users/123/progress', '/api/admin/users/[id]/progress'],
	['/api/admin/levels?role=admin', '/api/admin/levels'],
	['/%61dmin/levels', '/admin/levels'],
	['/api/%61dmin/levels', '/api/admin/levels'],
	['/admin/levels', '/(authenticated)/admin/(editor)/levels'],
	['/api/admin/levels', '/api/(private)/admin/levels'],
	['/distill/admin', '/admin'],
	['/management', '/admin'],
	['/admin/not-found', null],
	['/api/admin/not-found', null]
];

test('denied page, data, action, and API requests never reach downstream handlers', async () => {
	for (const [path, routeId] of protectedRoutes) {
		for (const method of ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']) {
			for (const { auth, status } of denied) {
				await assert.rejects(
					async () =>
						handleAdmin({
							event: request(path, auth, method, routeId),
							resolve: async () => assert.fail('Protected handler must not run')
						}),
					(error) => isHttpError(error, status),
					`${method} ${path} should return ${status}`
				);
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
