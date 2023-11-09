<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import Router from "svelte-spa-router";
  import Home from "./components/Home.svelte";
  const routes = {
    "/": wrap({
      component: Home,
      props: {},
    }),
  };
</script>

<div class="hero min-h-screen bg-base-200">
  <div class="hero-content text-center">
    <div class="max-w-md text-center">
      <Router {routes} />
    </div>
  </div>
</div>
