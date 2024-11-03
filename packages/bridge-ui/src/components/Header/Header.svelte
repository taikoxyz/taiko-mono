<script lang="ts">
  import { page } from '$app/stores';
  import BridgeTabs from '$components/Bridge/BridgeTabs.svelte';
  import { ConnectButton } from '$components/ConnectButton';
  import { IconFlipper } from '$components/Icon';
  import LogoWithTextDark from '$components/Logo/LogoWithTextDark.svelte';
  import LogoWithTextLight from '$components/Logo/LogoWithTextLight.svelte';
  import { drawerToggleId } from '$components/SideNavigation';
  import { ThemeButton } from '$components/ThemeButton';
  import { account } from '$stores/account';
  export let sideBarOpen = false;
  import { theme } from '$stores/theme';

  const handleSideBarOpen = () => {
    sideBarOpen = !sideBarOpen;
  };

  $: flipped = sideBarOpen;

  $: isBridgePage = $page.route.id === '/' || $page.route.id === '/nft';
  $: isTransactionsPage = $page.route.id === '/transactions';
</script>

<header
  class="
    sticky-top
    f-between-center
    justify-between
    z-30
    px-4
    py-[20px]

    glassy-background
    bg-grey-5/10
    dark:bg-grey-900/10
    lg:px-10
    lg:py-7
 ">
  <div class="flex justify-between items-center w-full">
    <div class="lg:w-[226px] w-auto">
      {#if $theme === 'light'}
        <LogoWithTextLight />
      {:else}
        <LogoWithTextDark />
      {/if}
    </div>

    {#if isBridgePage || isTransactionsPage}
      <BridgeTabs class="hidden lg:flex md:flex-1" />
    {/if}
    <div class="f-row">
      <ConnectButton connected={$account?.isConnected} class="justify-self-end" />
      <div class="hidden lg:inline-flex">
        <div class="v-sep my-auto mx-[8px] h-[24px]" />
        <ThemeButton />
      </div>
    </div>
  </div>
  <label for={drawerToggleId} class="ml-[10px] lg:hidden">
    <IconFlipper
      type="swap-rotate"
      iconType1="bars-menu"
      iconType2="x-close"
      selectedDefault="bars-menu"
      class="w-9 h-9 rounded-full"
      bind:flipped
      on:labelclick={handleSideBarOpen} />
  </label>
</header>
