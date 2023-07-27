<script lang="ts">
  import * as Sentry from '@sentry/svelte';
  import { ChevronDown, ExclamationTriangle } from 'svelte-heros-v2';
  import { UserRejectedRequestError } from 'wagmi';

  import { L1Chain, L2Chain } from '../chain/chains';
  import type { Chain } from '../domain/chain';
  import { srcChain } from '../store/chain';
  import { signer } from '../store/signer';
  import { pendingTransactions } from '../store/transaction';
  import { switchNetwork } from '../utils/switchNetwork';
  import {
    errorToast,
    successToast,
    warningToast,
  } from './NotificationToast.svelte';

  const switchChains = async (chain: Chain) => {
    if (!$signer) {
      errorToast('Please connect your wallet');
      return;
    }

    if (chain === $srcChain) {
      // Already on this chain
      return;
    }

    try {
      await switchNetwork(chain.id);
      successToast('Successfully changed chain.');
    } catch (error) {
      console.error(error);

      if (error instanceof UserRejectedRequestError) {
        warningToast('Switch chain request rejected.');
      } else {
        Sentry.captureException(error, { extra: { chainTo: chain.id } });

        errorToast('Error switching chain.');
      }
    }
  };

  $: cannotSwitch = $pendingTransactions && $pendingTransactions.length > 0;
</script>

<div class="dropdown dropdown-end mr-4">
  <button class="btn justify-around md:w-[194px]" disabled={cannotSwitch}>
    <span class="font-normal flex-1 text-left mr-2">
      {#if $srcChain}
        <span class="flex items-center">
          <img src={$srcChain.iconUrl} alt={$srcChain.name} />
          <span class="ml-2 hidden md:inline-block">{$srcChain.name}</span>
        </span>
      {:else}
        <span class="ml-2 flex items-center">
          <ExclamationTriangle class="mr-2" size="20" />
          <span class="hidden md:block">Invalid Chain</span>
        </span>
      {/if}
    </span>
    <ChevronDown size="20" />
  </button>
  <ul
    role="listbox"
    tabindex="0"
    class="dropdown-content rounded-box flex my-2 menu p-2 shadow bg-dark-2 w-[194px]">
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-sm"
        on:click={() => switchChains(L1Chain)}>
        <img src={L1Chain.iconUrl} alt={L1Chain.name} height={24} />
        <span class="pl-1.5 text-left flex-1">{L1Chain.name}</span>
      </button>
    </li>
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 rounded-sm"
        on:click={() => switchChains(L2Chain)}>
        <img src={L2Chain.iconUrl} alt={L2Chain.name} height={24} />
        <span class="pl-1.5 text-left flex-1">{L2Chain.name}</span>
      </button>
    </li>
  </ul>
</div>
