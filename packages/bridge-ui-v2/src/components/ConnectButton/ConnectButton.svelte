<script lang="ts">
  import { getAccount } from '@wagmi/core';
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { EthIcon, Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import { web3modal } from '$libs/connect';
  import { renderEthBalance } from '$libs/util/balance';
  import { noop } from '$libs/util/noop';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { ethBalance } from '$stores/balance';
  export let connected = false;

  let web3modalOpen = false;
  let unsubscribeWeb3Modal = noop;

  $: address = getAccount().address;

  function connectWallet() {
    if (web3modalOpen) return;
    web3modal.open();
  }

  function onWeb3Modal(state: { open: boolean }) {
    web3modalOpen = state.open;
  }

  onMount(() => {
    unsubscribeWeb3Modal = web3modal.subscribeState(onWeb3Modal);
  });

  onDestroy(unsubscribeWeb3Modal);
</script>

{#if connected}
  <Button
    class="hidden sm:flex pl-[14px] pr-[20px] h-[38px] mr-[8px] rounded-full card dark:md:glassy-gradient-card dark:md:glass-background-gradient flex-row"
    type="neutral"
    on:click={connectWallet}>
    <span class="body-regular f-items-center">
      <svelte:component this={EthIcon} size={20} />
      {#if $ethBalance >= 0}
        <span class="ml-[6px]">{renderEthBalance($ethBalance, 6)}</span>
      {:else}
        <Spinner /> <span>{$t('common.fetching_balance')}</span>
      {/if}
    </span>
    <div
      class="flex justify-center items-center text-center inline-flex dark:border-grey-500 border-grey-100 border-2 min-h-[30px] max-h-[30px] p-0 m-0 rounded-full px-2 mr-[-15px] space-x-[8px]">
      {#if address}
        <span class="text-secondary-content">{shortenAddress(address, 4, 6)}</span>
      {/if}
      <Icon type="chevron-down" size={16} />
    </div>
  </Button>
  <div class="flex sm:hidden">
    <w3m-button />
  </div>
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
