<script lang="ts">
  import '../app.css';
  import '../i18n';

  import { onDestroy, onMount } from 'svelte';

  import { AccountConnectionToast } from '$components/AccountConnectionToast';
  import { BridgePausedModal } from '$components/BridgePausedModal';
  import { Header } from '$components/Header';
  import { NotificationToast } from '$components/NotificationToast';
  import { SideNavigation } from '$components/SideNavigation';
  import { SwitchChainModal } from '$components/SwitchChainModal';
  import { WelcomeModal } from '$components/WelcomeModal';
  import { startWatching, stopWatching } from '$libs/wagmi';

  const syncPointer = ({ x, y }: { x: number; y: number }) => {
    document.documentElement.style.setProperty('--x', x.toFixed(2));
    document.documentElement.style.setProperty('--xp', (x / window.innerWidth).toFixed(2));
    document.documentElement.style.setProperty('--y', y.toFixed(2));
    document.documentElement.style.setProperty('--yp', (y / window.innerHeight).toFixed(2));
  };

  onMount(async () => {
    await startWatching();
    document.body.addEventListener('pointermove', syncPointer);
  });

  onDestroy(() => {
    stopWatching();
    document.body.removeEventListener('pointermove', syncPointer);
  });
</script>

<!-- App components -->
<SideNavigation>
  <Header />
  <main>
    <slot />
  </main>
</SideNavigation>

<!--
  The following UI is global and should be rendered 
  at the root of the app.
-->

<NotificationToast />

<AccountConnectionToast />

<SwitchChainModal />

<BridgePausedModal />

<WelcomeModal />
