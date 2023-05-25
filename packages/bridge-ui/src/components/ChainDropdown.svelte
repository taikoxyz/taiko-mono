<script lang="ts">
  import { UserRejectedRequestError } from '@wagmi/core';
  import { ChevronDown, ExclamationTriangle } from 'svelte-heros-v2';

  import { mainnetChain, taikoChain } from '../chain/chains';
  import type { Chain } from '../domain/chain';
  import { fromChain } from '../store/chain';
  import { signer } from '../store/signer';
  import { selectChain } from '../utils/selectChain';
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

    if (chain === $fromChain) {
      // Already on this chain
      return;
    }

    try {
      await selectChain(chain);
      successToast('Successfully changed chain.');
    } catch (error) {
      console.error(error);

      if (error instanceof UserRejectedRequestError) {
        warningToast('Switch chain request rejected.');
      } else {
        errorToast('Error switching chain.');
      }
    }
  };
</script>

<div class="dropdown dropdown-end mr-4">
  <!-- svelte-ignore a11y-label-has-associated-control -->
  <label
    role="button"
    tabindex="0"
    class="btn btn-md justify-around md:w-[194px]">
    <span class="font-normal flex-1 text-left mr-2">
      {#if $fromChain}
        <svelte:component this={$fromChain.icon} />
        <span class="ml-2 hidden md:inline-block">{$fromChain.name}</span>
      {:else}
        <span class="ml-2 flex items-center">
          <ExclamationTriangle class="mr-2" size="20" />
          <span class="hidden md:block">Invalid Chain</span>
        </span>
      {/if}
    </span>
    <ChevronDown size="20" />
  </label>
  <ul
    role="listbox"
    tabindex="0"
    class="dropdown-content rounded-box flex my-2 menu p-2 shadow bg-dark-2 w-[194px]">
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 justify-around"
        on:click={() => switchChains(mainnetChain)}>
        <svelte:component this={mainnetChain.icon} height={24} />
        <span class="pl-1.5 text-left flex-1">{mainnetChain.name}</span>
      </button>
    </li>
    <li>
      <button
        class="flex items-center px-2 py-4 hover:bg-dark-5 justify-around"
        on:click={() => switchChains(taikoChain)}>
        <svelte:component this={taikoChain.icon} height={24} />
        <span class="pl-1.5 text-left flex-1">{taikoChain.name}</span>
      </button>
    </li>
  </ul>
</div>
