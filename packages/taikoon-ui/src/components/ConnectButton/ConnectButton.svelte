<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { getAccount } from '@wagmi/core';
  import { onDestroy, onMount } from 'svelte';
  import { formatEther } from 'viem';
  import { zeroAddress } from 'viem';

  import { Spinner } from '$components/core/Spinner';
  import { getChainImage } from '$lib/chain';
  import { web3modal } from '$lib/connect';
  import { refreshUserBalance } from '$lib/util/balance';
  import { noop } from '$lib/util/noop';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { getBalance } from '$lib/wagmi';
  import { account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
  import { connectedSourceChain } from '$stores/network';
  import { config } from '$wagmi-config';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  import type { IAddress } from '../../types';
  import {
    addressClasses,
    buttonContentClasses,
    chainIconClasses,
    connectButtonClasses,
    connectedButtonClasses,
  } from './classes';

  export let connected = false;
  import { Icons } from '$components/core/Icons';
  const { CircleUserRegular: CircleUserIcon } = Icons;

  let web3modalOpen = false;
  let unsubscribeWeb3Modal = noop;

  function connectWallet() {
    if (web3modalOpen) return;
    web3modal.open();
  }

  function onWeb3Modal(state: { open: boolean }) {
    web3modalOpen = state.open;
  }

  $: currentChainId = $connectedSourceChain?.id;
  $: accountAddress = ($account?.address || zeroAddress) as IAddress;
  $: balance = $ethBalance || 0n;

  onMount(async () => {
    unsubscribeWeb3Modal = web3modal.subscribeState(onWeb3Modal);
    await refreshUserBalance();
  });

  onDestroy(unsubscribeWeb3Modal);

  $: balanceStr = '0.000';

  async function load() {
    const account = getAccount(config);
    if (!account.address) return;
    balance = await getBalance(account.address);

    if (parseFloat(formatEther(balance)) > 10) {
      balanceStr = parseFloat(formatEther(balance)).toFixed(1);
    } else {
      balanceStr = parseFloat(formatEther(balance)).toFixed(3);
    }
  }

  $: $account, load();
</script>

{#if connected}
  <button on:click={connectWallet} class={connectedButtonClasses}>
    <img
      alt="chain icon"
      class={chainIconClasses}
      src={(currentChainId && getChainImage(currentChainId)) || 'chains/ethereum.svg'} />
    {#if windowSize !== 'md'}
      <span class={buttonContentClasses}
        >{`Ξ ${balanceStr}`}
        <span class={addressClasses}>
          {#await shortenAddress(accountAddress, 5, 2)}
            ...
          {:then displayAddress}
            {displayAddress}
          {/await}
        </span>
      </span>{/if}
  </button>
{:else}
  <button class={connectButtonClasses} on:click={connectWallet}>
    {#if web3modalOpen}
      <Spinner size="sm" />
      {#if windowSize !== 'md'}
        Connecting
      {/if}
    {:else}
      <CircleUserIcon size="16" />
      {#if windowSize !== 'md'}
        Connect Wallet{/if}
    {/if}
  </button>
{/if}

<ResponsiveController bind:windowSize />
