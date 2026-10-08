<script lang="ts">
	import { SignUp } from 'svelte-clerk';
</script>

<svelte:head>
	<title>Sign up · Distill</title>
</svelte:head>

<main class="auth-page">
	<SignUp />
</main>

<style>
	.auth-page {
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 2rem 1rem;
	}
</style>
