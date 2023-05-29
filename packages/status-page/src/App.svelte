<script lang="ts">
  import { wrap } from "svelte-spa-router/wrap";
  import QueryProvider from "./components/providers/QueryProvider.svelte";
  import Router from "svelte-spa-router";
  import Home from "./pages/home/Home.svelte";
  import { setupI18n } from "./i18n";
  import Navbar from "./components/Navbar.svelte";
  setupI18n({ withLocale: "en" });

  const routes = {
    "/": wrap({
      component: Home,
      props: {
        enableL3: import.meta.env.VITE_ENABLE_L3,
      },
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
