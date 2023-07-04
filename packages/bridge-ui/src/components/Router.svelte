<script lang="ts">
  import SvelteRouter from 'svelte-spa-router';

  import Home from '../pages/home/Home.svelte';

  // TODO: add a NoFound component
  const routes = {
    '/:tab?': Home,
  };
</script>

<SvelteRouter {routes} />
