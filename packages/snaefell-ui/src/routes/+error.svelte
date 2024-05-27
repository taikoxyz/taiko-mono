<script>
  import { page } from '$app/stores';
</script>

<svelte:head>
  <title>Snaefell | Error</title>
</svelte:head>

{#if $page && $page.error && $page.error.message}
  <h1>{$page.error.message}</h1>
{/if}
