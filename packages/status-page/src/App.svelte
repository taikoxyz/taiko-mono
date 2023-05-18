<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import Home from "./pages/home/Home.svelte";
  import { setupI18n } from "./i18n";
  import Navbar from "./components/Navbar.svelte";
  import { ethers } from "ethers";
  import { layer } from "./store/layer";
  import { Layer } from "./domain/layer";
  setupI18n({ withLocale: "en" });

  const routes = {
    "/": wrap({
      component: Home,
    }),
  };
</script>

<QueryProvider>
  <main class="px-6">
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
