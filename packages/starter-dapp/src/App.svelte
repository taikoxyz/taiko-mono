<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import { SvelteToast } from "@zerodevx/svelte-toast";
  import type { SvelteToastOptions } from "@zerodevx/svelte-toast";
  import { configureChains, createClient } from "@wagmi/core";
  import { publicProvider } from "@wagmi/core/providers/public";
  import { jsonRpcProvider } from "@wagmi/core/providers/jsonRpc";
  import { CoinbaseWalletConnector } from "@wagmi/core/connectors/coinbaseWallet";
  import { WalletConnectConnector } from "@wagmi/core/connectors/walletConnect";
  import { MetaMaskConnector } from "@wagmi/core/connectors/metaMask";

  import Home from "./pages/home/Home.svelte";
  import { setupI18n } from "./i18n";
  import Navbar from "./components/Navbar.svelte";
  import { wagmiClient } from "./store/wagmi";

  setupI18n({ withLocale: "en" });
  import {
    CHAIN_ID_MAINNET,
    CHAIN_ID_TAIKO,
    mainnet,
    taiko,
  } from "./domain/chain";
  import SwitchEthereumChainModal from "./components/modals/SwitchEthereumChainModal.svelte";
  import { ethers } from "ethers";
  import { providers } from "./store/providers";

  const providerMap: Map<number, ethers.providers.JsonRpcProvider> = new Map<
    number,
    ethers.providers.JsonRpcProvider
  >();

  providerMap.set(
    CHAIN_ID_MAINNET,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L1_RPC_URL)
  );
  providerMap.set(
    CHAIN_ID_TAIKO,
    new ethers.providers.JsonRpcProvider(import.meta.env.VITE_L2_RPC_URL)
  );
  providers.set(providerMap);

  const { chains: wagmiChains, provider } = configureChains(
    [mainnet, taiko],
    [
      publicProvider(),
      jsonRpcProvider({
        rpc: (chain) => ({
          http: providerMap.get(chain.id).connection.url,
        }),
      }),
    ]
  );

  $wagmiClient = createClient({
    autoConnect: true,
    provider,
    connectors: [
      new MetaMaskConnector({
        chains: wagmiChains,
      }),
      new CoinbaseWalletConnector({
        chains: wagmiChains,
        options: {
          appName: import.meta.env.VITE_APP_NAME,
        },
      }),
      new WalletConnectConnector({
        chains: wagmiChains,
        options: {
          qrcode: true,
        },
      }),
    ],
  });

  providers.set(providerMap);

  const toastOptions: SvelteToastOptions = {
    dismissable: false,
    duration: 4000,
    pausable: false,
  };

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
  <SvelteToast options={toastOptions} />
  <SwitchEthereumChainModal />
</QueryProvider>

<style global lang="postcss">
  @tailwind base;
  @tailwind components;
  @tailwind utilities;

  main {
    font-family: "Inter", sans-serif;
  }
</style>
