<script>
  import { page } from '$app/stores';
</script>

<svelte:head>
  <title>Taikoons | Error</title>
</svelte:head>

{#if $page && $page.error && $page.error.message}
  <h1>{$page.error.message}</h1>
{/if}
