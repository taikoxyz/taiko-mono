<script lang="ts">
  import { onDestroy } from 'svelte';

  import { chainIcons, type ChainID, getChainName } from '$libs/chain';

  import { isMobileStore } from './state';

  export let chainId: ChainID;

  const chainName = getChainName(Number(chainId));
  const icon = chainIcons[Number(chainId)];

  let isMobile = false;

  const unsubscribe = isMobileStore.subscribe((value: boolean) => {
    isMobile = value;
  });

  onDestroy(unsubscribe);
</script>

<div class="flex {isMobile ? 'justify-items-start' : 'items-stretch self-center'}">
  <img src={icon} alt="chain-logo" class="rounded-full w-5 h-5 hidden md:block mr-2" />
  <span class={isMobile ? 'font-bold' : ''}>{chainName}</span>
</div>
