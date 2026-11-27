<script lang="ts">
	import { UserProfile } from 'svelte-clerk';
	import { resolve } from '$app/paths';
</script>

<svelte:head><title>Account settings · Distill</title></svelte:head>

<!-- account settings (#28) use Clerk's built-in profile: email addresses (#29), password (#30),
connected accounts and sessions. the catch-all route lets Clerk use paths for its own tabs, like
/app/account/security -->
<main class="account">
	<header>
		<h1 class="display">Account settings</h1>
		<p class="muted">
			Manage your email addresses, password and connected accounts. Your progress is kept no matter
			which one you sign in with.
		</p>
	</header>

	<UserProfile path={resolve('/app/account/[...rest]', { rest: '' })} routing="path" />
</main>

<style>
	.account {
		display: grid;
		justify-items: center;
		gap: var(--space-5);
		max-width: var(--page-width);
		margin: 0 auto;
		padding: var(--space-7) var(--page-gutter) var(--space-8);
	}

	header {
		width: 100%;
		max-width: 55rem;
	}

	h1 {
		margin: 0 0 var(--space-2);
		font-size: var(--text-3xl);
	}

	p {
		margin: 0;
	}

	/* Clerk's profile card is wide; let it shrink on phones instead of scrolling the page */
	.account :global(.cl-rootBox),
	.account :global(.cl-cardBox) {
		max-width: 100%;
	}
</style>
