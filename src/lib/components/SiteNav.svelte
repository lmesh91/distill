<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { SignOutButton, useClerkContext } from 'svelte-clerk';
	import { accountLinks, primaryLinks, visibleLinks, type NavLink } from '$lib/navigation/links';
	import logo from '$lib/assets/distill-logo.png';
	import ThemeToggle from './ThemeToggle.svelte';

	const clerk = useClerkContext();
	// the server passes Clerk's auth state in the page data, so this is right on the first render;
	// <Show> renders nothing until Clerk's script loads, which made the nav jump after hydration
	// it also updates on its own when the user signs out
	const signedIn = $derived(Boolean(clerk.auth.userId));
	const links = $derived(visibleLinks(primaryLinks, signedIn));
	const authLinks = $derived(visibleLinks(accountLinks, signedIn));

	// the sign-in and sign-up pages are catch-all routes for Clerk's sub-steps, so resolve
	// needs their route ids; an empty rest parameter gives the plain /sign-in path
	const hrefs = {
		'/': resolve('/'),
		'/app': resolve('/app'),
		'/app/lean': resolve('/app/lean'),
		'/sign-in': resolve('/(auth)/sign-in/[...sign_in]', { sign_in: '' }),
		'/sign-up': resolve('/(auth)/sign-up/[...sign_up]', { sign_up: '' })
	} satisfies Record<NavLink['href'], string>;
</script>

<header class="site-header">
	<nav class="site-nav" aria-label="Primary">
		<a class="brand" href={resolve('/')}>
			<img src={logo} alt="Distill" width="92" height="32" />
		</a>

		<ul class="links">
			{#each links as link (link.href)}
				<li>
					<a
						href={hrefs[link.href]}
						aria-current={link.isActive(page.url.pathname) ? 'page' : undefined}
					>
						{link.label}
					</a>
				</li>
			{/each}
		</ul>

		<div class="account">
			<ThemeToggle />
			{#if signedIn}
				<!-- ends the Clerk session, then returns to the signed-out home page -->
				<SignOutButton redirectUrl="/" class="button small sign-out" />
			{:else}
				{#each authLinks as link (link.href)}
					<a
						class={['button', 'small', link.href === '/sign-up' && 'primary']}
						href={hrefs[link.href]}
						aria-current={link.isActive(page.url.pathname) ? 'page' : undefined}
					>
						{link.label}
					</a>
				{/each}
			{/if}
		</div>
	</nav>
</header>

<style>
	.site-header {
		border-bottom: var(--border-width) solid var(--color-border);
		background: var(--color-surface);
	}

	.site-nav {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: var(--space-2) var(--space-6);
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-3) var(--page-gutter);
	}

	.brand {
		display: inline-flex;
		align-items: center;
	}

	.brand img {
		display: block;
		width: auto;
		height: 2rem;
		/* the logo is pixel art, so keep its edges sharp when scaled */
		image-rendering: pixelated;
	}

	/* the logo blue is dark on dark backgrounds, so lift it a little */
	:global(:root[data-theme='dark']) .brand img {
		filter: brightness(1.45);
	}

	@media (prefers-color-scheme: dark) {
		:global(:root:not([data-theme='light'])) .brand img {
			filter: brightness(1.45);
		}
	}

	.links {
		display: flex;
		flex-wrap: wrap;
		gap: var(--space-1) var(--space-2);
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.links a {
		display: inline-block;
		padding: var(--space-1) var(--space-2);
		border-radius: var(--radius-sm);
		color: var(--color-text-muted);
		font-weight: var(--weight-medium);
		text-decoration: none;
	}

	.links a:hover {
		color: var(--color-ink);
		background: var(--color-surface-sunken);
	}

	/* the current page gets the yellow marker highlight */
	.links a[aria-current='page'] {
		background: var(--color-highlight);
		color: var(--color-on-highlight);
		font-weight: var(--weight-bold);
	}

	/* on the sign-in and sign-up pages, their button gets the same marker as a current link */
	.account a[aria-current='page'] {
		background: var(--color-highlight);
		color: var(--color-on-highlight);
	}

	.account {
		display: flex;
		align-items: center;
		gap: var(--space-2);
		margin-left: auto;
	}
</style>
