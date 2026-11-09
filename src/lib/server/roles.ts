import { error } from '@sveltejs/kit';

/**
 * Administrator status lives in Clerk `publicMetadata.role` and is copied into
 * the session token as `metadata.role`. See docs/api/README.md.
 */
export function isAdmin(sessionClaims: CustomJwtSessionClaims | null | undefined): boolean {
	return sessionClaims?.metadata?.role === 'admin';
}

/** Require a verified administrator session before reading data or making changes. */
export function requireAdmin(locals: Pick<App.Locals, 'auth'>): string {
	const { userId, sessionClaims } = locals.auth();
	if (!userId) error(401, 'Unauthorized');
	if (!isAdmin(sessionClaims)) error(403, 'Forbidden');
	return userId;
}
