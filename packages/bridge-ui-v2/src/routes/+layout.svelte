<script lang="ts">
  import '../app.css';
  import '$libs/i18n';

  import { onDestroy, onMount } from 'svelte';

  import { Header } from '$components/Header';
  import { SideNavigation } from '$components/SideNavigation';
  import { startWatching, stopWatching } from '$libs/wagmi';

  onMount(startWatching);
  onDestroy(stopWatching);
</script>

<SideNavigation>
  <Header />
  <main class="mt-8 md:mt-14">
    <slot />
  </main>
</SideNavigation>
