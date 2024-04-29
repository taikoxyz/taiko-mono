<script lang="ts">
  import { getAccount } from '@wagmi/core';
  import { onDestroy, onMount } from 'svelte';
  import { formatEther } from 'viem';
  import { zeroAddress } from 'viem';

  import { getChainImage } from '$lib/chain';
  import { web3modal } from '$lib/connect';
  import { refreshUserBalance } from '$lib/util/balance';
  import { classNames } from '$lib/util/classNames';
  import { noop } from '$lib/util/noop';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { getBalance } from '$lib/wagmi';
  import { account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
  import { connectedSourceChain } from '$stores/network';
  import { Button } from '$ui/Button';
  import { config } from '$wagmi-config';

  import type { IAddress } from '../../types';
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

  $: currentChainId = $connectedSourceChain?.id;
  $: accountAddress = ($account?.address || zeroAddress) as IAddress;
  $: balance = $ethBalance || 0n;

  onMount(async () => {
    unsubscribeWeb3Modal = web3modal.subscribeState(onWeb3Modal);
    await refreshUserBalance();
  });

  onDestroy(unsubscribeWeb3Modal);

  connectedSourceChain.subscribe(async () => {
    const account = getAccount(config);
    if (!account.address) return;
    balance = await getBalance(account.address);
  });
</script>

{#if connected}
  <button
    on:click={connectWallet}
    class={classNames(
      'border border-divider-border',
      'bg-gradient-to-r from-grey-500-10 to-grey-500-20',
      'rounded-full',
      'flex',
      'items-center',
      'gap-2',
      'font-bold',
    )}>
    <img
      alt="chain icon"
      class="w-[24px] ml-1"
      src={(currentChainId && getChainImage(currentChainId)) || 'chains/ethereum.svg'} />
    <span
      class={classNames(
        'flex items-center',
        'justify-center',
        'text-secondary-content',
        'p-1',
        'gap-2',
        'md:text-normal',
        'text-sm',
      )}
      >{`Ξ ${parseFloat(formatEther(balance)).toFixed(3)}`}
      <span
        class={classNames('flex', 'rounded-full', 'p-2.5', 'bg-neutral-background', 'border border-divider-border')}>
        {#await shortenAddress(accountAddress, 4, 6)}
          ...
        {:then displayAddress}
          {displayAddress}
        {/await}
      </span>
    </span>
  </button>
{:else}
  <Button type="primary" loading={web3modalOpen} iconLeft={'CircleUserRegular'} on:click={connectWallet}>
    {#if web3modalOpen}
      Connecting
    {:else}Connect Wallet
    {/if}
  </Button>
{/if}
