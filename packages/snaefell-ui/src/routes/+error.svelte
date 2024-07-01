<script>
  import { page } from '$app/stores';
</script>

<svelte:head>
  <title>Snaefell | Error</title>
</svelte:head>

{#if $page && $page.error && $page.error.message}
  <h1>Error</h1>
  <p class="text-center px-2">{$page.error.message}</p>
{/if}
