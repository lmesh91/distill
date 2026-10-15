/**
 * turns a user-supplied redirect target into a path on this site, or returns `fallback` 
 * if it is missing or points to another site.
 * this stops links like `/sign-in?redirect_url=https://bad.example` from sending
 * signed-in users off-site
 */
export function safeRedirectPath(target: string | null, origin: string, fallback: string): string {
	if (!target) return fallback;

	try {
		const url = new URL(target, origin);
		if (url.origin !== origin) return fallback;
		return url.pathname + url.search + url.hash;
	} catch {
		return fallback;
	}
}
