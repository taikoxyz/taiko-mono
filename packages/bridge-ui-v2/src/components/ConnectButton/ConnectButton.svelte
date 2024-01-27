<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { getChainImage } from '$libs/chain';
  import { web3modal } from '$libs/connect';
  import { refreshUserBalance, renderEthBalance } from '$libs/util/balance';
  import { noop } from '$libs/util/noop';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
  import { network } from '$stores/network';

  export let connected = false;

  let web3modalOpen = false;
  let unsubscribeWeb3Modal = noop;

  function connectWallet() {
    if (web3modalOpen) return;
    web3modal.open();
  }

  function onWeb3Modal(state: { open: boolean }) {
    web3modalOpen = state.open;
  }

  $: currentChainId = $network?.id;
  $: accountAddress = $account?.address || '';

  $: balance = $ethBalance || 0n;

  onMount(async () => {
    unsubscribeWeb3Modal = web3modal.subscribeState(onWeb3Modal);
    await refreshUserBalance();
  });

  onDestroy(unsubscribeWeb3Modal);
</script>

<!-- {#if connected} -->
<!-- <w3m-button class="test" size="md" /> -->
{#if connected}
  <button
    on:click={connectWallet}
    class="rounded-[20px] flex items-center pl-[8px] pr-[3px] max-h-[48px] wc-parent-glass !border-solid !border-[1px] !border-gray-800 gap-2 font-bold">
    <img alt="chain icon" class="w-[24px]" src={(currentChainId && getChainImage(currentChainId)) || ''} />
    <span class="flex items-center text-secondary-content justify-self-start gap-4"
      >{renderEthBalance(balance, 6)}
      <span
        class="flex items-center text-tertiary-content btn-glass-bg rounded-[20px] px-[10px] py-[4px] min-h-[38px] bg-tertiary-background">
        {shortenAddress(accountAddress, 4, 6)}
      </span>
    </span>
  </button>
{:else}
  <ActionButton
    priority="primary"
    class="!max-w-[215px] !min-h-[32px] !f-items-center !py-0"
    loading={web3modalOpen}
    on:click={connectWallet}>
    <div class="flex items-center body-regular space-x-2">
      {#if web3modalOpen}
        <span>{$t('wallet.status.connecting')}</span>
      {:else}
        <Icon type="user-circle" class="md-show-block" fillClass="fill-white" />
        <span>{$t('wallet.connect')}</span>
      {/if}
    </div>
  </ActionButton>
{/if}

<style>
  .wc-parent-glass {
    background: rgba(255, 255, 255, 0.02);
    &:hover {
      background: rgb(255 255 255 / 5%);
    }
  }
  .btn-glass-bg {
    @apply border-solid border-[1px] border-neutral-background;
    background: rgba(255, 255, 255, 0.05);
  }
</style>
