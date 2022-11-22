<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import Navbar from "./components/Navbar.svelte";

  import { themeChange } from "theme-change";
  import { onMount } from "svelte";
  import Home from "./pages/home/Home.svelte";
  import { setupI18n } from "./i18n";
  import { BridgeType } from "./domain/bridge";
  import ETHBridge from "./eth/bridge";
  import { bridges } from "./store/bridge";

  onMount(() => {
    themeChange(false);
  });

  setupI18n({ withLocale: "en" });

  const ethBridge = new ETHBridge();

  bridges.update((store) => {
    store.set(BridgeType.ETH, ethBridge);
    return store;
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
  </div>
</QueryProvider>

<style global lang="postcss">
  @tailwind base;
  @tailwind components;
  @tailwind utilities;
</style>
