<script lang="ts">
  import '../app.css';

  import Header from '$components/Header';
  import SideNavigation from '$components/SideNavigation';
  import { startWatching, stopWatching } from '$libs/wagmi';
  import { onDestroy, onMount } from 'svelte';

  onMount(startWatching)
  onDestroy(stopWatching)
</script>

<SideNavigation>
  <Header />
  <main class="flex justify-center md:px-10 md:py-7 mt-8 md:mt-14">
    <slot />
  </main>
</SideNavigation>
