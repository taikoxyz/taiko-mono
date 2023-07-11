<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { noop } from 'svelte/internal';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import { web3modal } from '$libs/connect';

  export let connected = false;

  let web3modalOpen = false;
  let unsubscribeWeb3Modal = noop;

  function connectWallet() {
    web3modal.openModal();
  }

  function onWeb3Modal(state: { open: boolean }) {
    web3modalOpen = state.open;
  }

  onMount(() => {
    unsubscribeWeb3Modal = web3modal.subscribeModal(onWeb3Modal);
  });

  onDestroy(unsubscribeWeb3Modal);
</script>

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
