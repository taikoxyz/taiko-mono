<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import type { BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { chainUrlMap } from '$libs/chain';

  export let item: BridgeTransaction;

  import { createEventDispatcher, onDestroy } from 'svelte';

  import { Icon } from '$components/Icon';
  import { isMobile as isMobileStore } from '$stores/isMobile';

  import ChainSymbolName from './ChainSymbolName.svelte';
  import Status from './Status.svelte';

  const dispatch = createEventDispatcher();

  let isMobile = false;

  const unsubscribe = isMobileStore.subscribe((value: boolean) => {
    isMobile = value;
  });

  onDestroy(unsubscribe);

  const handleClick = () => dispatch('click');

  const handlePress = () => dispatch('press');

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

  let attrs = isMobile ? { role: 'button' } : {};
</script>

<!-- We disable these warnings as we dynamically add the role -->
<!-- svelte-ignore a11y-no-noninteractive-tabindex -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div {...attrs} tabindex="0" on:click={handleClick} on:keydown={handlePress} class="flex text-white h-[80px] w-full">
  {#if isMobile}
    <div class="flex text-white h-[80px] w-full">
      <div class="flex-col">
        <div class="flex">
          <ChainSymbolName chainId={item.srcChainId} />
          <i role="img" aria-label="arrow to" class="mx-auto px-2">
            <Icon type="arrow-right" />
          </i>
          <ChainSymbolName chainId={item.destChainId} />
        </div>
        <div class="py-2 flex flex-col justify-center">
          {formatEther(item.amount ? item.amount : BigInt(0))}
          {item.symbol}
        </div>
      </div>
    </div>
  {:else}
    <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-row justify-left items-stretch">
      <ChainSymbolName chainId={item.srcChainId} />
    </div>

    <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-row justify-left items-stretch">
      <ChainSymbolName chainId={item.destChainId} />
    </div>
    <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
      {formatEther(item.amount ? item.amount : BigInt(0))}
      {item.symbol}
    </div>
  {/if}

  <div class="w-1/4 md-w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    <Status bridgeTx={item} />
  </div>
  <div class="hidden md:flex w-1/5 px-4 py-2 flex flex-col justify-center items-stretch">
    <a href={`${chainUrlMap[Number(item.srcChainId)].explorerUrl}/tx/${item.hash}`} target="_blank">
      {$t('activities.link.explorer')}
    </a>
  </div>
</div>
