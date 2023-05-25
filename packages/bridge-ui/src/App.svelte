<script lang="ts">
  import { onDestroy, onMount } from 'svelte';

  import Navbar from './components/Navbar.svelte';
  import NotificationToast from './components/NotificationToast.svelte';
  import Router from './components/Router.svelte';
  import SwitchChainModal from './components/SwitchChainModal.svelte';
  import { startWatching, stopWatching } from './wagmi/watcher';

  onMount(startWatching);
  onDestroy(stopWatching);
</script>

<main>
  <Navbar />
  <Router />
</main>

<NotificationToast />
<SwitchChainModal />
