<script>
  import * as Sentry from '@sentry/svelte';
  import { ArrowRight } from 'svelte-heros-v2';
  import { UserRejectedRequestError } from 'wagmi';

  import { mainnetChain, taikoChain } from '../../chain/chains';
  import { destChain, srcChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { pendingTransactions } from '../../store/transaction';
  import { switchNetwork } from '../../utils/switchNetwork';
  import {
    errorToast,
    successToast,
    warningToast,
  } from '../NotificationToast.svelte';

  const toggleChains = async () => {
    if (!$signer) {
      warningToast('Please, connect your wallet.');
      return;
    }

    const chain = $srcChain === mainnetChain ? taikoChain : mainnetChain;

    try {
      await switchNetwork(chain.id);
      successToast('Successfully changed chain.');
    } catch (error) {
      console.error(error);

      if (error instanceof UserRejectedRequestError) {
        warningToast('Switch chain request canceled.');
      } else {
        Sentry.captureException(error, {
          extra: {
            chainTo: chain.id,
          },
        });

        errorToast('Error switching chain.');
      }
    }
  };

  $: cannotToggle = $pendingTransactions && $pendingTransactions.length > 0;
</script>

<div
  class="flex items-center justify-between w-full px-4 md:px-7 py-6 text-sm md:text-lg">
  <div class="flex items-center w-2/5 justify-center">
    {#if $srcChain}
      <svelte:component this={$srcChain.icon} />
      <span class="ml-2">{$srcChain.name}</span>
    {:else}
      <svelte:component this={mainnetChain.icon} />
      <span class="ml-2">{mainnetChain.name}</span>
    {/if}
  </div>

  <button
    disabled={cannotToggle}
    on:click={toggleChains}
    class="btn rounded btn-sm toggle-chain">
    <ArrowRight size="16" />
  </button>

  <div class="flex items-center w-2/5 justify-center">
    {#if $destChain}
      <svelte:component this={$destChain.icon} />
      <span class="ml-2">{$destChain.name}</span>
    {:else}
      <svelte:component this={taikoChain.icon} />
      <span class="ml-2">{taikoChain.name}</span>
    {/if}
  </div>
</div>
