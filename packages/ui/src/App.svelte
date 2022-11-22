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
  import { bridges, chainIdToBridgeAddress } from "./store/bridge";
  import { CHAIN_MAINNET, CHAIN_TKO } from "./domain/chain";

  onMount(() => {
    themeChange(false);
  });

  setupI18n({ withLocale: "en" });

  const ethBridge = new ETHBridge();

  bridges.update((store) => {
    store.set(BridgeType.ETH, ethBridge);
    return store;
  });

  chainIdToBridgeAddress.update((store) => {
    store.set(CHAIN_TKO.id, import.meta.env.VITE_TAIKO_BRIDGE_ADDRESS);
    store.set(CHAIN_MAINNET.id, import.meta.env.VITE_MAINNET_BRIDGE_ADDRESS);
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
