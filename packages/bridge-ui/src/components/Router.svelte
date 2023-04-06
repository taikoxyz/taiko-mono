<script lang="ts">
  import SvelteRouter from 'svelte-spa-router';
  import { wrap } from 'svelte-spa-router/wrap';
  import Home from '../pages/home/Home.svelte';

  const routes = {
    '/:tab?': wrap({
      component: Home,
      props: {},
      userData: {},
    }),
  };
</script>

<SvelteRouter {routes} />
