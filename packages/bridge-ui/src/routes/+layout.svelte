<script lang="ts">
  import '../app.css';
  import '../i18n';

  import { onDestroy, onMount } from 'svelte';

  import { browser } from '$app/environment';
  import { AccountConnectionToast } from '$components/AccountConnectionToast';
  import { BridgePausedModal } from '$components/BridgePausedModal';
  import { Header } from '$components/Header';
  import { NotificationToast } from '$components/NotificationToast';
  import { SideNavigation } from '$components/SideNavigation';
  import { SwitchChainModal } from '$components/SwitchChainModal';
  import {
    desktopQuery,
    initializeMediaQueries,
    mediaQueryHandler,
    mobileQuery,
    tabletQuery,
  } from '$libs/util/responsiveCheck';
  import { startWatching, stopWatching } from '$libs/wagmi';

  let sideBarOpen = false;

  const syncPointer = ({ x, y }: { x: number; y: number }) => {
    document.documentElement.style.setProperty('--x', x.toFixed(2));
    document.documentElement.style.setProperty('--xp', (x / window.innerWidth).toFixed(2));
    document.documentElement.style.setProperty('--y', y.toFixed(2));
    document.documentElement.style.setProperty('--yp', (y / window.innerHeight).toFixed(2));
  };

  onMount(async () => {
    await startWatching();
    initializeMediaQueries();

    if (desktopQuery) {
      desktopQuery.addEventListener('change', mediaQueryHandler);
      document.body.addEventListener('pointermove', syncPointer);
    }
    if (tabletQuery) {
      tabletQuery.addEventListener('change', mediaQueryHandler);
    }
    if (mobileQuery) {
      mobileQuery.addEventListener('change', mediaQueryHandler);
    }
  });

  onDestroy(() => {
    stopWatching();
    if (browser) {
      document.body.removeEventListener('pointermove', syncPointer);
    }
    if (desktopQuery) {
      desktopQuery.removeEventListener('change', mediaQueryHandler);
    }
    if (tabletQuery) {
      tabletQuery.removeEventListener('change', mediaQueryHandler);
    }
    if (mobileQuery) {
      mobileQuery.removeEventListener('change', mediaQueryHandler);
    }
  });
</script>

<!-- App components -->
<Header bind:sideBarOpen />
<SideNavigation bind:sideBarOpen>
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
