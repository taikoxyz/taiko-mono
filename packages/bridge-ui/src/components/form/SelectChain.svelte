<script>
  import ArrowRight from '../icons/ArrowRight.svelte';
  import { fromChain, toChain } from "../../store/chain";
  import { CHAIN_MAINNET, CHAIN_TKO } from '../../domain/chain';

  function toggleChains() {
    fromChain.update(val => val === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET);
    toChain.update(val => val === CHAIN_MAINNET ? CHAIN_TKO : CHAIN_MAINNET);
  }
</script>
<div class="flex items-center justify-between w-full p-8 py-6 text-lg">
  <div class="flex items-center w-2/5 justify-center">
    <svelte:component this={$fromChain.icon} />
    <span class="ml-2">From {$fromChain.name}</span>
  </div>
  
  <button on:click={toggleChains} class="btn btn-square btn-xs"><ArrowRight /></button>
  <div class="flex items-center w-2/5 justify-center">
    <svelte:component this={$toChain.icon} />
    <span class="ml-2">To {$toChain.name}</span>
  </div>
</div>