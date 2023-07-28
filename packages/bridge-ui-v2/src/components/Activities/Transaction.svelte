<script lang="ts">
  import { sepolia } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import { EthIcon, TaikoIcon } from '$components/Icon';
  import type { BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { chainUrlMap, taikoChain } from '$libs/chain';

  export let item: BridgeTransaction;

  import { createEventDispatcher } from 'svelte';

  import ChainIcon from './ChainIcon.svelte';

  const dispatch = createEventDispatcher();

  function handleClick() {
    dispatch('click');
  }

  function handlePress() {
    dispatch('press');
  }

  const mapStatusToText = (status: MessageStatus) => {
    switch (status) {
      case 1:
        return 'Pending';
      case 2:
        return 'Claimed';
      case 3:
        return 'Failed';
      default:
        return 'Unknown';
    }
  };
</script>

<div role="button" tabindex="0" on:click={handleClick} on:keydown={handlePress} class="flex text-white h-[80px] w-full">
  <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    <ChainIcon chainId={item.srcChainId} />
  </div>
  <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    <ChainIcon chainId={item.destChainId} />
  </div>
  <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    {formatEther(item.amount ? item.amount : BigInt(0))}
    {item.symbol}
  </div>
  <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    {item.status ? mapStatusToText(item.status) : 'Unknown'}
  </div>
  <div class="hidden md:flex w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    <a href={`${chainUrlMap[Number(item.srcChainId)].explorerUrl}/tx/${item.hash}`} target="_blank">
      {$t('activities.link.explorer')}
    </a>
  </div>
</div>
