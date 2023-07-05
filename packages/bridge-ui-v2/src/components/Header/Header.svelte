<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { LogoWithText } from '$components/Logo';
  import { drawerToggleId } from '$components/SideNavigation';
  import { web3modal } from '$libs/connect';
  import { onDestroy, onMount } from 'svelte';
  import { Spinner } from '$components/Spinner';

  export let connected = false;

  let web3modalOpen = false;
  let unsubscribeWeb3Modal: () => void;

  function connectWallet() {
    web3modal.openModal();
  }

  function onWeb3Modal(state: { open: boolean }) {
    if (state.open) {
      web3modalOpen = true;
    } else {
      web3modalOpen = false;
    }
  }

  onMount(() => {
    unsubscribeWeb3Modal = web3modal.subscribeModal(onWeb3Modal);
  });

  onDestroy(() => {
    unsubscribeWeb3Modal();
  });
</script>

<header
  class="
    sticky-top
    f-between-center
    z-10
    px-4
    py-[20px]
    border-b
    border-b-divider-border
    glassy-primary-background
    md:border-b-0
    md:px-10
    md:py-7
    md:justify-end">
  <LogoWithText class="w-[77px] h-[20px] md:hidden" />

  <div class="f-items-center justify-end space-x-[10px]">
    <!-- 
      We are gonna make use of Web3Modal core button when we are connected,
      which comes with interesting features out of the box.
      https://docs.walletconnect.com/2.0/web/web3modal/html/wagmi/components
     -->
    {#if connected}
      <w3m-core-button balance="show" />
    {:else}
      <!-- TODO: fixing the width for English. i18n? -->
      <Button class="px-[20px] py-2 rounded-full w-[215px]" type="neutral" on:click={connectWallet}>
        <span class="body-regular f-items-center space-x-2">
          {#if web3modalOpen}
            <Spinner />
            <span>{$t('wallet.status.connecting')}</span>
          {:else}
            <Icon type="user-circle" class="md-show-block" />
            <span>{$t('wallet.connect')}</span>
          {/if}
        </span>
      </Button>
    {/if}

    <label for={drawerToggleId} class="md:hidden">
      <Icon type="bars-menu" />
    </label>
  </div>
</header>
