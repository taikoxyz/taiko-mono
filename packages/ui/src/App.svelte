<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import Navbar from "./components/Navbar.svelte";

  import { themeChange } from "theme-change";
  import { onMount } from "svelte";
  import Footer from "./components/Footer.svelte";
  import Home from "./pages/home/Home.svelte";

  onMount(() => {
    themeChange(false);
  });

  const routes = {
    "/": wrap({
      component: Home,
      props: {},
      userData: {},
    }),
  };
</script>

<QueryProvider>
  <div class="h-screen w-full" style="margin: 0 auto;">
    <Navbar />
    <Router {routes} />
    <Footer />
  </div>
</QueryProvider>

<style global lang="postcss">
  @tailwind base;
  @tailwind components;
  @tailwind utilities;
</style>
