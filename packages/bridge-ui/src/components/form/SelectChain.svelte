<script>
  import { switchNetwork } from '@wagmi/core';
  import { ArrowRight } from 'svelte-heros-v2';
  import { fromChain, toChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { bridgeChains, mainnetChain, taikoChain } from '../../chain/chains';
  import { errorToast, successToast } from '../Toast.svelte';
  import { selectChain } from '../../utils/selectChain';
  import { bridgeChainType } from '../../store/bridge';

  const toggleChains = async () => {
    if (!$signer) {
      errorToast('Please connect your wallet');
      return;
    }

    const [chain1, chain2] = bridgeChains[$bridgeChainType];

    // Toggling between the two current bridge chains
    const chainToSelect = $fromChain.id === chain1.id ? chain2 : chain1;

    try {
      await selectChain(chainToSelect.id, [chain1, chain2]);
      successToast('Successfully changed chain');
    } catch (e) {
      console.error(e);
      errorToast('Error switching chain');
    }
  };
</script>

<div
  class="flex items-center justify-between w-full px-4 md:px-7 py-6 text-sm md:text-lg text-white">
  <div class="flex items-center w-2/5 justify-center">
    {#if $fromChain}
      <svelte:component this={$fromChain.icon} />
      <span class="ml-2">{$fromChain.name}</span>
    {:else}
      <svelte:component this={mainnetChain.icon} />
      <span class="ml-2">{mainnetChain.name}</span>
    {/if}
  </div>

  <button on:click={toggleChains} class="btn btn-square btn-sm toggle-chain">
    <ArrowRight size="16" />
  </button>

  <div class="flex items-center w-2/5 justify-center">
    {#if $toChain}
      <svelte:component this={$toChain.icon} />
      <span class="ml-2">{$toChain.name}</span>
    {:else}
      <svelte:component this={taikoChain.icon} />
      <span class="ml-2">{taikoChain.name}</span>
    {/if}
  </div>
</div>
