<script lang="ts">
  import { getAccount } from '@wagmi/core';
  import { onDestroy, onMount } from 'svelte';
  import { formatEther } from 'viem';

  import { Spinner } from '$components/core/Spinner';
  import { getChainImage } from '$lib/chain';
  import { web3modal } from '$lib/connect';
  import { refreshUserBalance } from '$lib/util/balance';
  import { classNames } from '$lib/util/classNames';
  import { noop } from '$lib/util/noop';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { ZeroXAddress } from '$lib/util/ZeroXAddress';
  import { getBalance } from '$lib/wagmi';
  import { account } from '$stores/account';
  import { ethBalance } from '$stores/balance';
  import { connectedSourceChain } from '$stores/network';
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
  $: accountAddress = ($account?.address || ZeroXAddress) as IAddress;
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

  import { Icons } from '$components/core/Icons';
  const { CircleUserRegular: CircleUserIcon } = Icons;
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
      'h-[44px]',
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
        class={classNames(
          'flex',
          'rounded-full',
          'px-2.5',
          'py-2',
          'bg-neutral-background',
          'border border-divider-border',
        )}>
        {#await shortenAddress(accountAddress, 4, 6)}
          ...
        {:then displayAddress}
          {displayAddress}
        {/await}
      </span>
    </span>
  </button>
{:else}
  <button
    class={classNames(
      'w-max',
      'h-[44px]',
      'bg-primary',
      'rounded-full',
      'flex flex-row',
      'justify-center',
      'items-center',
      'px-4',
      'gap-4',
      'font-medium',
    )}
    on:click={connectWallet}>
    {#if web3modalOpen}
      <Spinner size="sm" />
      Connecting
    {:else}
      <CircleUserIcon size="16" />
      Connect Wallet
    {/if}
  </button>
{/if}
