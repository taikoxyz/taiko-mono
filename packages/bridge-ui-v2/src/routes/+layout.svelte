<script lang="ts">
  import '../app.css';
  import '../i18n';

  import { onDestroy, onMount } from 'svelte';

  import { Header } from '$components/Header';
  import { SideNavigation } from '$components/SideNavigation';
  import { startWatching, stopWatching } from '$libs/wagmi';
  import { account } from '$stores/account';

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
