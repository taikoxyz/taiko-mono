<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import { SvelteToast } from "@zerodevx/svelte-toast";
  import { configureChains } from '@wagmi/core';
  import { publicProvider } from '@wagmi/core/providers/public'
  
  import { mainnet, taiko } from "./domain/chain";
  import Navbar from "./components/Navbar.svelte";
  import Home from "./pages/home/Home.svelte";
  import { setupI18n } from "./i18n";
  import { BridgeType } from "./domain/bridge";
  import ETHBridge from "./eth/bridge";
  import { bridges, chainIdToBridgeAddress } from "./store/bridge";
  import { CHAIN_MAINNET, CHAIN_TKO } from "./domain/chain";

  const { chains, provider } = configureChains(
    [mainnet, taiko],
    [publicProvider()]
  );

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
  <main>
    <Navbar />
    <Router {routes} />
  </main>
  <SvelteToast />
</QueryProvider>

<style global lang="postcss">
  @tailwind base;
  @tailwind components;
  @tailwind utilities;

  main {
    margin: 0;
    font-family: 'Inter', sans-serif;
  }
</style>
