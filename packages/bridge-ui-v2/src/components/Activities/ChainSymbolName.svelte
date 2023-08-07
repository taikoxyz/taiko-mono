<script lang="ts">
  import { chainIcons, type ChainID, getChainName } from '$libs/chain';

  export let chainId: ChainID;
  const chainName = getChainName(Number(chainId));
  const icon = chainIcons[Number(chainId)];
</script>

<div class="flex md:items-stretch self-center justify-items-start'}">
  <img src={icon} alt="chain-logo" class="rounded-full w-5 h-5 hidden md:block mr-2" />
  <span class="md:font-bold font-normal">{chainName}</span>
</div>
