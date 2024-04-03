<script lang="ts">
  import { chainConfig } from '$chainConfig';
  import type { ChainID } from '$libs/chain';

  export let chainId: ChainID;
  const chainName = chainConfig[Number(chainId)]?.name || 'Unknown Chain';
  const icon = chainConfig[Number(chainId)]?.icon || 'Unknown Chain';
</script>

<div class="flex md:items-stretch self-center justify-items-start'} {$$props.class}">
  <img src={icon} alt="chain-logo" class="rounded-full w-5 h-5 mr-2" />
  <span>{chainName}</span>
</div>
