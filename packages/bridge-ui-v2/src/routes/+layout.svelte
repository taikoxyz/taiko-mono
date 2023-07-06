<script lang="ts">
  import '../app.css';
  import '../i18n';

  import { onDestroy, onMount } from 'svelte';

  import { Header } from '$components/Header';
  import { SideNavigation } from '$components/SideNavigation';
  import { startWatching, stopWatching } from '$libs/wagmi';
  import { account } from '$stores/account';
  import NotificationToast, {
    errorToast,
    successToast,
    warningToast,
  } from '$components/NotificationToast/NotificationToast.svelte';

  $: connected = Boolean($account?.isConnected);

  onMount(startWatching);
  onDestroy(stopWatching);
</script>

<SideNavigation>
  <Header {connected} />
  <main>
    <slot />
  </main>
</SideNavigation>

<div class="flex space-x-4">
  <button on:click={() => successToast()}>Success</button>
  <button on:click={() => errorToast()}>Error</button>
  <button on:click={() => warningToast()}>Warning</button>
</div>

<NotificationToast />
