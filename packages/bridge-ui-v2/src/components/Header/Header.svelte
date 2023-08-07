<script lang="ts">
  import { page } from '$app/stores';
  import BridgeTabs from '$components/Bridge/BridgeTabs.svelte';
  import { ConnectButton } from '$components/ConnectButton';
  import { Icon } from '$components/Icon';
  import { LogoWithText } from '$components/Logo';
  import { drawerToggleId } from '$components/SideNavigation';
  import { account } from '$stores/account';

  $: isBridgePage = $page.route.id === '/' || $page.route.id === '/nft';
</script>

<header
  class="
    sticky-top
    f-between-center
    justify-between
    z-10
    px-4
    py-[20px]
    border-b
    border-b-divider-border
    glassy-primary-background
    md:border-b-0
    md:px-10
    md:py-7
 ">
  <LogoWithText width={150} height={50} class="md:hidden" />

  <div class="flex justify-end md:f-between-center w-full">
    {#if isBridgePage}
      <!-- TODO: show tabs on mobile somewhere else -->
      <BridgeTabs class="hidden md:flex" />
    {:else}
      <div></div>
    {/if}

    <ConnectButton connected={$account?.isConnected} />
  </div>

  <label for={drawerToggleId} class="ml-[10px] md:hidden">
    <Icon type="bars-menu" />
  </label>
</header>
