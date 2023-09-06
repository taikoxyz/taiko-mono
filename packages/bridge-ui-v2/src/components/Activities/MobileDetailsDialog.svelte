<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { Icon } from '$components/Icon';
  import { Tooltip } from '$components/Tooltip';
  import type { BridgeTransaction } from '$libs/bridge';
  import { noop } from '$libs/util/noop';
  import { uid } from '$libs/util/uid';

  import ChainSymbolName from './ChainSymbolName.svelte';
  import Status from './Status.svelte';

  export let closeDetails = noop;
  export let detailsOpen = false;

  export let selectedItem: BridgeTransaction | null;

  let tooltipOpen = false;
  const openToolTip = (event: Event) => {
    event.stopPropagation();
    tooltipOpen = !tooltipOpen;
  };
  let dialogId = `dialog-${uid()}`;
</script>

<dialog id={dialogId} class="modal modal-bottom" class:modal-open={detailsOpen}>
  <div
    class="modal-box relative border border-neutral-background px-6 py-[30px] dark:glassy-gradient-card dark:glass-background-gradient">
    <button class="absolute right-6 top-[30px]" on:click={closeDetails}>
      <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
    </button>

    <h3 class="title-body-bold mb-7 text-primary-content">{$t('processing_fee.title')}</h3>

    {#if selectedItem}
      <ul class="space-y-[15px] body-small-regular w-full">
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('chain.from')}</h4>
          <ChainSymbolName chainId={selectedItem.srcChainId} />
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('chain.to')}</h4>
          <ChainSymbolName chainId={selectedItem.destChainId} />
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('inputs.amount.label')}</h4>
          <span>{formatEther(selectedItem.amount ? selectedItem.amount : BigInt(0))} {selectedItem.symbol}</span>
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">
            <div class="f-items-center space-x-1">
              <button on:click={openToolTip}>
                <span>{$t('activities.header.status')}</span>
              </button>
              <Tooltip position="right" bind:tooltipOpen>TODO: add description about status here</Tooltip>
            </div>
          </h4>
          <div class="f-items-center space-x-1">
            <Status bridgeTx={selectedItem} />
          </div>
        </li>
        <li class="f-between-center">
          <h4 class="text-secondary-content">{$t('activities.header.explorer')}</h4>
          <a
            class="flex justify-start content-center"
            href={`${chainConfig[Number(selectedItem.srcChainId)].urls.explorer}/tx/${selectedItem.hash}`}
            target="_blank">
            {$t('activities.link.explorer')}
            <Icon type="arrow-top-right" />
          </a>
        </li>
      </ul>
    {/if}
  </div>

  <button class="overlay-backdrop" on:click={closeDetails} />
</dialog>
