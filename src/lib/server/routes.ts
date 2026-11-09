import type { RequestEvent } from '@sveltejs/kit';

/** Normalize matched route IDs for use by server authorization policies. */
export function normalizedRouteId(event: Pick<RequestEvent, 'route' | 'url'>): string {
	// Unmatched routes use the raw pathname; encoded lookalikes still end in a 404.
	if (event.route.id === null) return event.url.pathname;

	// Matched IDs cover encoded URLs, data requests, rerouting, and base paths.
	// Only whole route-group segments are organizational rather than URL segments.
	return (
		event.route.id
			.split('/')
			.filter((segment) => !/^\([^)]+\)$/.test(segment))
			.join('/') || '/'
	);
}
