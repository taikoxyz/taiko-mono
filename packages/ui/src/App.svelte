<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import { EVENTS } from "./domain/eventTracker";
  import Deposit from "./pages/deposit/Deposit.svelte";
  import Router from "svelte-spa-router";
  import Navbar from "./components/Navbar.svelte";

  import { themeChange } from "theme-change";
  import { onMount } from "svelte";
  import { BridgeType } from "./domain/bridge";
  import type { Bridge } from "./domain/bridge";
  import Footer from "./components/Footer.svelte";
  import { bridges } from "./store/bridge";
  import { ETHBridge } from "./eth/bridge";

  onMount(() => {
    themeChange(false);
  });

  const ethBridge: Bridge = new ETHBridge();

  bridges.update((store) => {
    store.set(BridgeType.ETH, ethBridge);
    return store;
  });

  const onRouteLoaded = (event: unknown) => {
    const viewEventName = (
      event as { detail: { userData: { viewEvent: string } } }
    )?.detail?.userData?.viewEvent;
    if (viewEventName) {
      // track with mixpanel
    }
  };

  const routes = {
    "/": wrap({
      component: Deposit,
      props: {},
      userData: {
        viewEvent: EVENTS.HOME.VIEW,
      },
    }),
  };
</script>

<QueryProvider>
  <div class="h-screen w-full" style="margin: 0 auto;">
    <Navbar />
    <Router {routes} on:routeLoaded={onRouteLoaded} />
    <Footer />
  </div>
</QueryProvider>

<style global lang="postcss">
  @tailwind base;
  @tailwind components;
  @tailwind utilities;
</style>
