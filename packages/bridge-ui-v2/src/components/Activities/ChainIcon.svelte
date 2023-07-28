<script lang="ts">
  import { sepolia } from '@wagmi/core';

  import { EthIcon, TaikoIcon } from '$components/Icon';
  import { type ChainID,taikoChain } from '$libs/chain';

  export let chainId: ChainID;
</script>

{#if Number(chainId) === sepolia.id}
  <div class="f-items-center space-x-2">
    <i role="img" aria-label="Ethereum">
      <EthIcon size={20} />
    </i>
    <span class="hidden md:block">Sepolia</span>
  </div>
{:else if Number(chainId) === taikoChain.id}
  <div class="f-items-center space-x-2">
    <i role="img" aria-label="Taiko">
      <TaikoIcon size={20} />
    </i>
    <span class="hidden md:block">Taiko</span>
  </div>
{:else}
  {chainId}
{/if}
