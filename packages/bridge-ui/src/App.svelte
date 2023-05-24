<script lang="ts">
  import Navbar from './components/Navbar.svelte';
  import NotificationToast from './components/NotificationToast.svelte';
  import SwitchChainModal from './components/SwitchChainModal.svelte';
  import Router from './components/Router.svelte';
  import { startWatching, stopWatching } from './wagmi/watcher';
  import { onDestroy, onMount } from 'svelte';

  onMount(startWatching);
  onDestroy(stopWatching);
</script>

<main>
  <Navbar />
  <Router />
</main>

<NotificationToast />
<SwitchChainModal />

<style>
  main {
    font-family: 'Inter', sans-serif;
  }
</style>
