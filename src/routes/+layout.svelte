<script lang="ts">
  import type { Snippet } from 'svelte';
  import { ClerkProvider } from 'svelte-clerk';
  import SiteNav from '$lib/components/SiteNav.svelte';

  let { children }: { children: Snippet } = $props();
</script>

<ClerkProvider>
  <SiteNav />
  {@render children()}
</ClerkProvider>
