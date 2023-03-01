<script lang="ts">
  import BaseQueries from "./BaseQueries.svelte";

  import { QueryClient, QueryClientProvider } from "@sveltestack/svelte-query";

  const queryClient = new QueryClient();
</script>

<QueryClientProvider client={queryClient}>
  <BaseQueries>
    <slot />
  </BaseQueries>
</QueryClientProvider>
