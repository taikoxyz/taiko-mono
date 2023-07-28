<script lang="ts">
  import { sepolia } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import { EthIcon, TaikoIcon } from '$components/Icon';
  import type { BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { chainUrlMap, taikoChain } from '$libs/chain';

  export let item: BridgeTransaction;

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

<div class="flex text-white h-[80px] w-full">
  <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    {#if Number(item.srcChainId) === sepolia.id}
      <div class="f-items-center space-x-2">
        <i role="img" aria-label="Ethereum">
          <EthIcon size={20} />
        </i>
        <span>Sepolia</span>
      </div>
    {:else if Number(item.srcChainId) === taikoChain.id}
      <div class="f-items-center space-x-2">
        <i role="img" aria-label="Taiko">
          <TaikoIcon size={20} />
        </i>
        <span>Taiko</span>
      </div>
    {:else}
      {item.srcChainId}
    {/if}
  </div>
  <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    {#if Number(item.destChainId) === sepolia.id}
      <div class="f-items-center space-x-2">
        <i role="img" aria-label="Ethereum">
          <EthIcon size={20} />
        </i>
        <span>Sepolia</span>
      </div>
    {:else if Number(item.destChainId) === taikoChain.id}
      <div class="f-items-center space-x-2">
        <i role="img" aria-label="Taiko">
          <TaikoIcon size={20} />
        </i>
        <span>Taiko</span>
      </div>
    {:else}
      item.destChainId
    {/if}
  </div>
  <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    {formatEther(item.amount ? item.amount : BigInt(0))}
    {item.symbol}
  </div>
  <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    {item.status ? mapStatusToText(item.status) : 'Unknown'}
  </div>
  <div class="w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    <a href={`${chainUrlMap[Number(item.srcChainId)].explorerUrl}/tx/${item.hash}`} target="_blank">
      {$t('activities.link.explorer')}
    </a>
  </div>
</div>
