<script lang="ts">
  import Navbar from './components/Navbar.svelte';
  import Toast from './components/Toast.svelte';
  import SwitchEthereumChainModal from './components/modals/SwitchEthereumChainModal.svelte';
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

<Toast />
<SwitchEthereumChainModal />

<style>
  main {
    font-family: 'Inter', sans-serif;
  }
</style>
