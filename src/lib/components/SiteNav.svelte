<script lang="ts">
	import { resolve } from '$app/paths';
	import { page } from '$app/state';
	import { primaryLinks } from '$lib/navigation/links';
</script>

<header class="site-header">
	<nav class="site-nav" aria-label="Primary">
		<a class="brand" href={resolve('/')}>Distill</a>

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
	</nav>
</header>

<style>
	.site-header {
		border-bottom: 1px solid #d0d0d0;
		background: #fff;
	}

	.site-nav {
		display: flex;
		flex-wrap: wrap;
		align-items: center;
		gap: 0.5rem 2rem;
		max-width: 75rem;
		margin: 0 auto;
		padding: 0.75rem 1rem;
	}

	.brand {
		font-size: 1.25rem;
		font-weight: 700;
		color: #333;
		text-decoration: none;
	}

	.links {
		display: flex;
		flex-wrap: wrap;
		gap: 0.25rem 1.25rem;
		margin: 0;
		padding: 0;
		list-style: none;
	}

	.links a {
		display: inline-block;
		padding: 0.25rem 0;
		color: #555;
		text-decoration: none;
		border-bottom: 2px solid transparent;
	}

	.links a:hover {
		color: #333;
	}

	.links a[aria-current='page'] {
		color: #333;
		font-weight: 600;
		border-bottom-color: #333;
	}

	a:focus-visible {
		outline: 2px solid #1f6feb;
		outline-offset: 2px;
	}
</style>
