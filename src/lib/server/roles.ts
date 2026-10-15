/**
 * Administrator status lives in Clerk `publicMetadata.role` and is copied into
 * the session token as `metadata.role`. See docs/decisions/0001-admin-status-storage.md.
 *
 * Works anywhere you have `locals` (page/layout loads and API +server.ts routes):
 *   const { userId, sessionClaims } = locals.auth();
 *   if (!userId) error(401, 'Unauthorized');
 *   if (!isAdmin(sessionClaims)) error(403, 'Forbidden');
 *
 * Actually enforcing this on admin pages and routes is #37.
 */
export function isAdmin(sessionClaims: CustomJwtSessionClaims | null | undefined): boolean {
	return sessionClaims?.metadata?.role === 'admin';
}
