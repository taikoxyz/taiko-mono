<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import Navbar from "./components/Navbar.svelte";

  import { onMount } from "svelte";
  import Footer from "./components/Footer.svelte";
  import Home from "./pages/home/Home.svelte";
  import { configureChains, createClient } from "@wagmi/core";
  import { mainnet, taiko } from "./domain/chain";
  import { publicProvider } from "wagmi/providers/public";
  import { wagmiClient } from "./store/wagmi";

  const { chains, provider } = configureChains(
    [mainnet, taiko],
    [publicProvider()]
  );

  const wagmi = createClient({
    autoConnect: true,
    provider,
  });

  wagmiClient.set(wagmi);

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
    <Footer />
  </main>
</QueryProvider>

<style global lang="postcss">
  @tailwind base;
  @tailwind components;
  @tailwind utilities;

  main {
    margin: 0;
  }
</style>
