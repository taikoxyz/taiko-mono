<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import Home from "./pages/home/Home.svelte";
  import { setupI18n } from "./i18n";
  import Navbar from "./components/Navbar.svelte";
  import { ethers } from "ethers";
  setupI18n({ withLocale: "en" });

  console.log(import.meta.env.VITE_L1_RPC_URL);
  const l1Provider = new ethers.providers.JsonRpcProvider(
    import.meta.env.VITE_L1_RPC_URL
  );
  const l2Provider = new ethers.providers.JsonRpcProvider(
    import.meta.env.VITE_L2_RPC_URL
  );

  const routes = {
    "/": wrap({
      component: Home,
      props: {
        l1Provider: l1Provider,
        l1TaikoAddress: import.meta.env.VITE_TAIKO_L1_ADDRESS,
        l2Provider: l2Provider,
        l2TaikoAddress: import.meta.env.VITE_TAIKO_L2_ADDRESS,
        l1ExplorerUrl: import.meta.env.VITE_L1_EXPLORER_URL,
        l2ExplorerUrl: import.meta.env.VITE_L2_EXPLORER_URL,
        feeTokenSymbol: import.meta.env.FEE_TOKEN_SYMBOL || "TKO",
      },
      userData: {},
    }),
  };
</script>

<QueryProvider>
  <main>
    <Navbar />
    <Router {routes} />
  </main>
</QueryProvider>

<style global lang="postcss">
  @tailwind base;
  @tailwind components;
  @tailwind utilities;

  main {
    font-family: "Inter", sans-serif;
  }

  .green {
    color: #7cfc00;
  }

  .red {
    color: #ff9494;
  }

  .yellow {
    color: #eed202;
  }
</style>
