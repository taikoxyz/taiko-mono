<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { EthIcon, Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import { web3modal } from '$libs/connect';
  import { renderEthBalance } from '$libs/util/balance';
  import { noop } from '$libs/util/noop';
  import { ethBalance } from '$stores/balance';
  export let connected = false;

  let web3modalOpen = false;
  let unsubscribeWeb3Modal = noop;

  function connectWallet() {
    if (web3modalOpen) return;
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

{#if connected}
  <Button class="hidden sm:flex  pl-[10px] pr-[15px] h-[40px] mr-[8px] rounded-full" type="neutral" on:click={connectWallet}>
    <span class="body-regular f-items-center">
      <svelte:component this={EthIcon} size={24} />
      {#if $ethBalance >= 0}
        <span class="ml-[6px]">{renderEthBalance($ethBalance)}</span>
      {:else}
        <Spinner /> <span>Fetching balance...</span>
      {/if}
    </span>
  </Button>
  <w3m-core-button class="h-[40px]" balance="hide" />
{:else}
  <Button class="px-[20px] py-2 rounded-full w-[215px]" type="neutral" loading={web3modalOpen} on:click={connectWallet}>
    <span class="body-regular f-items-center space-x-2">
      {#if web3modalOpen}
        <span>{$t('wallet.status.connecting')}</span>
      {:else}
        <Icon type="user-circle" class="md-show-block" />
        <span>{$t('wallet.connect')}</span>
      {/if}
    </span>
  </Button>
{/if}
