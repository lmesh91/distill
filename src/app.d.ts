/// <reference types="svelte-clerk/env" />
// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
declare global {
	namespace App {
		// interface Error {}
		// interface Locals {}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}

	/**
	 * Extra claims we add to Clerk's session token (Clerk Dashboard → Sessions →
	 * Customize session token). See docs/decisions/0001-admin-status-storage.md.
	 */
	interface CustomJwtSessionClaims {
		metadata?: {
			role?: 'admin';
		};
	}
}

export {};
