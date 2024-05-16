<script>
  import { page } from '$app/stores';
</script>

{#if $page && $page.error && $page.error.message}
  <h1>{$page.error.message}</h1>
{/if}
