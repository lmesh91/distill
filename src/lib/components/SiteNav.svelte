<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { Show, SignOutButton } from 'svelte-clerk';
	import { primaryLinks } from '$lib/navigation/links';
	import logo from '$lib/assets/distill-logo.png';
</script>

<header class="site-header">
	<nav class="site-nav" aria-label="Primary">
		<a class="brand" href={resolve('/')}>
			<img src={logo} alt="Distill" width="92" height="32" />
		</a>

		<ul class="links">
			{#each primaryLinks as link (link.href)}
				<li>
					<a
						href={resolve(link.href)}
						aria-current={link.isActive(page.url.pathname) ? 'page' : undefined}
					>
						{link.label}
					</a>
				</li>
			{/each}
		</ul>

		<div class="account">
			<!-- Ends the Clerk session, then returns to the signed-out home page. -->
			<Show when="signed-in">
				<SignOutButton redirectUrl="/" class="button small sign-out" />
			</Show>
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
		color: var(--color-ink);
		font-weight: var(--weight-bold);
	}

	.account {
		margin-left: auto;
	}
</style>
