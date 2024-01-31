<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { CloseButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import type { BridgeTransaction } from '$libs/bridge';
  import { noop } from '$libs/util/noop';
  import { uid } from '$libs/util/uid';

  import ChainSymbolName from './ChainSymbolName.svelte';
  import { StatusInfoDialog } from './Status';
  import Status from './Status/Status.svelte';

  export let closeDetails = noop;
  export let detailsOpen = false;

  export let selectedItem: BridgeTransaction;

  const dispatch = createEventDispatcher();

  let openStatusDialog = false;

  let tooltipOpen = false;
  const openToolTip = (event: Event) => {
    event.stopPropagation();
    tooltipOpen = !tooltipOpen;
  };
  let dialogId = `dialog-${uid()}`;

  const handleStatusDialog = () => {
    openStatusDialog = !openStatusDialog;
  };

  const handleInsufficientFunds = (e: CustomEvent) => {
    dispatch('insufficientFunds', e.detail);
  };
</script>

<dialog id={dialogId} class="modal modal-bottom" class:modal-open={detailsOpen}>
  <div class="modal-box relative w-full bg-neutral-background !p-0 !pb-[20px]">
    <div class="w-full pt-[35px] px-[24px]">
      <CloseButton onClick={closeDetails} />
      <h3 class="font-bold">{$t('processing_fee.title')}</h3>
    </div>
    <div class="h-sep my-[20px]" />
    <div class="w-full px-[24px] text-left">
      {#if selectedItem}
        <ul class="space-y-[15px] body-small-regular w-full">
          <li class="f-between-center">
            <h4 class="text-secondary-content">{$t('common.from')}</h4>
            <ChainSymbolName chainId={selectedItem.srcChainId} />
          </li>
          <li class="f-between-center">
            <h4 class="text-secondary-content">{$t('common.to')}</h4>
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
                  <span>{$t('transactions.header.status')}</span>
                </button>
                <button on:click={handleStatusDialog} class="flex justify-start content-center">
                  <Icon type="question-circle" />
                </button>
              </div>
            </h4>
            <div class="f-items-center space-x-1">
              <Status bridgeTx={selectedItem} on:insufficientFunds={handleInsufficientFunds} />
            </div>
          </li>
          <li class="f-between-center">
            <h4 class="text-secondary-content">{$t('transactions.header.explorer')}</h4>
            <a
              class="flex justify-start content-center"
              href={`${chainConfig[Number(selectedItem.srcChainId)].urls.explorer}/tx/${selectedItem.hash}`}
              target="_blank">
              {$t('transactions.link.explorer')}
              <Icon type="arrow-top-right" />
            </a>
          </li>
        </ul>
      {/if}
    </div>

    <button class="overlay-backdrop" on:click={closeDetails} />
  </div>
</dialog>

<StatusInfoDialog bind:modalOpen={openStatusDialog} noIcon />
