<script>
  import { switchNetwork } from '@wagmi/core';
  import { ArrowRight } from 'svelte-heros-v2';
  import { fromChain, toChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { ethers } from 'ethers';
  import { mainnetChain, taikoChain } from '../../chain/chains';
  import { errorToast, successToast } from '../Toast.svelte';

  const toggleChains = async () => {
    try {
      const chain = $fromChain === mainnetChain ? taikoChain : mainnetChain;
      await switchNetwork({
        chainId: chain.id,
      });
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      await provider.send('eth_requestAccounts', []);

      fromChain.set(chain);
      toChain.set(chain === mainnetChain ? taikoChain : mainnetChain);

      signer.set(provider.getSigner());
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

  <button
    on:click={toggleChains}
    class="btn btn-square btn-sm toggle-chain"
    disabled={!$signer}><ArrowRight size="16" /></button>
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
