<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther, hexToBigInt } from 'viem';

  import { CloseButton } from '$components/Button';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import ExplorerLink from '$components/ExplorerLink/ExplorerLink.svelte';
  import { Icon } from '$components/Icon';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { formatTimestamp } from '$libs/util/formatTimestamp';
  import { getBlockFromTxHash } from '$libs/util/getBlockFromTxHash';
  import { geBlockTimestamp } from '$libs/util/getBlockTimestamp';
  import { getLogger } from '$libs/util/logger';
  import { noop } from '$libs/util/noop';

  import ChainSymbolName from '../ChainSymbolName.svelte';
  import { StatusInfoDialog } from '../Status';
  import Status from '../Status/Status.svelte';

  const log = getLogger('DesktopDetailsDialog');
  const dialogId = `dialog-${crypto.randomUUID()}`;

  export let detailsOpen = false;
  export let bridgeTx: BridgeTransaction;
  export let closeDetails = noop;

  let openStatusDialog = false;

  let tooltipOpen = false;
  const openToolTip = () => {
    tooltipOpen = !tooltipOpen;
  };

  const handleStatusDialog = () => {
    openStatusDialog = !openStatusDialog;
  };
  $: from = bridgeTx.message?.from || null;
  $: to = bridgeTx.message?.to || null;

  $: srcTxHash = bridgeTx.srcTxHash || null;
  $: destTxHash = bridgeTx.destTxHash || null;

  $: srcChainId = bridgeTx.srcChainId || null;
  $: destChainId = bridgeTx.destChainId || null;
  $: destOwner = bridgeTx.message?.destOwner || null;

  $: bridgeTx && getClaimedDate();
  $: bridgeTx && getInitiatedDate();

  $: claimedBy = bridgeTx.claimedBy || null;
  $: isRelayer = false;

  $: if (claimedBy !== to && claimedBy !== destOwner && bridgeTx.status === MessageStatus.DONE) {
    isRelayer = true;
  } else {
    isRelayer = false;
  }

  $: paidFee = formatEther(bridgeTx.fee ? bridgeTx.fee : BigInt(0));

  let initiatedAt = '';
  let claimedAt = '';

  const getInitiatedDate = async () => {
    const blockTimestamp = await geBlockTimestamp(bridgeTx.srcChainId, hexToBigInt(bridgeTx.blockNumber));
    initiatedAt = formatTimestamp(Number(blockTimestamp));
  };

  const getClaimedDate = async () => {
    log('destTxHash', bridgeTx.destTxHash, 'destChainId', bridgeTx.destChainId);
    try {
      const blockNumber = await getBlockFromTxHash(bridgeTx.destTxHash, bridgeTx.destChainId);
      log('blockNumber', blockNumber);
      const blockTimestamp = await geBlockTimestamp(bridgeTx.destChainId, blockNumber);
      log('blockTimestamp', blockTimestamp);
      claimedAt = formatTimestamp(Number(blockTimestamp));
      log('claimedAt', claimedAt);
    } catch (error) {
      log('error', error);
    }
  };
</script>

<dialog
  use:closeOnEscapeOrOutsideClick={{ enabled: detailsOpen, callback: closeDetails, uuid: dialogId }}
  id={dialogId}
  class="modal h-full min-h-[100%]"
  class:modal-open={detailsOpen}>
  <div
    class="modal-box relative f-col justify-between w-full min-h-[100%] rounded-[0px] bg-neutral-background !p-0 !pb-[20px]">
    <div class="w-full pt-[35px] px-[24px]">
      <CloseButton onClick={closeDetails} />
      <h3 class="font-bold">{$t('transactions.details_dialog.title')}</h3>
      <div class="h-sep my-[20px] mx-[-24px]" />
    </div>
    <div class="flex-grow w-full">
      <div class="self-start">
        <div class="w-full px-[24px] text-left">
          {#if bridgeTx}
            <ul class="body-small-regular w-full">
              <!-- From -->
              <li class="f-between-center space-y-[8px]">
                <h4 class="text-secondary-content">{$t('common.from')}</h4>
                <ChainSymbolName chainId={bridgeTx.srcChainId} />
              </li>
              <li class="f-between-center space-y-[8px]">
                <div class="text-secondary-content">{$t('common.tx_hash')}</div>
                <span>
                  {#if srcTxHash}
                    <ExplorerLink
                      class="text-secondary-content"
                      urlParam={srcTxHash}
                      category="tx"
                      chainId={Number(srcChainId)}
                      shorten />
                  {:else}
                    -
                  {/if}
                </span>
              </li>

              <!-- Spacer -->
              <div class="h-[24px]" />

              <!-- To -->
              <li class="f-between-center space-y-[8px]">
                <h4 class="text-secondary-content">{$t('common.to')}</h4>
                <ChainSymbolName chainId={bridgeTx.destChainId} />
              </li>

              <li class="f-between-center space-y-[8px]">
                <div class="text-secondary-content">{$t('common.tx_hash')}</div>
                {#if destTxHash}
                  <ExplorerLink
                    class="text-secondary-content"
                    urlParam={destTxHash}
                    category="tx"
                    chainId={Number(destChainId)}
                    shorten />
                {:else}
                  -
                {/if}
              </li>
            </ul>

            <div class="h-sep my-[20px] mx-[-24px]" />

            <ul class="space-y-[8px] body-small-regular w-full">
              <!-- Status -->
              <li class="f-between-center space-y-[8px]">
                <h4 class="text-secondary-content">
                  <div class="f-items-center space-x-1">
                    <button on:click|stopPropagation={openToolTip}>
                      <span>{$t('transactions.header.status')}</span>
                    </button>
                    <button on:click={handleStatusDialog} class="flex justify-start content-center">
                      <Icon type="question-circle" />
                    </button>
                  </div>
                </h4>
                <div class="f-items-center space-x-1">
                  <Status bridgeTxStatus={bridgeTx.status} {bridgeTx} textOnly />
                </div>
              </li>

              <!-- Sender -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('transactions.details_dialog.sender_address')}</div>
                {#if from}
                  <div><ExplorerLink category="address" urlParam={from} chainId={Number(srcChainId)} shorten /></div>
                {/if}
              </li>

              <!-- Recipient -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('transactions.details_dialog.recipient_address')}</div>
                {#if to}
                  <div><ExplorerLink category="address" urlParam={to} chainId={Number(destChainId)} shorten /></div>
                {/if}
              </li>

              <!-- Dest owner -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('transactions.details_dialog.destination_owner')}</div>
                {#if destOwner}
                  <div>
                    <ExplorerLink category="address" urlParam={destOwner} chainId={Number(destChainId)} shorten />
                  </div>
                {/if}
              </li>

              <!-- Amount -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('common.amount')}</div>
                <span>{formatEther(bridgeTx.amount ? bridgeTx.amount : BigInt(0))} {bridgeTx.symbol}</span>
              </li>

              <!-- Date initiated -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('transactions.details_dialog.initated_date')}</div>
                <div>{initiatedAt || '-'}</div>
              </li>

              <!-- Claimed by -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('transactions.details_dialog.claimed_by')}</div>
                <div>
                  {#if isRelayer}
                    <span>{$t('common.relayer')}</span>
                  {:else if claimedBy}
                    <ExplorerLink category="address" urlParam={claimedBy} chainId={Number(destChainId)} shorten />
                  {:else}
                    -
                  {/if}
                </div>
              </li>

              <!-- Claim date -->
              <li class="f-between-center">
                <div class="text-secondary-content">Claim date</div>
                <div>{claimedAt || '-'}</div>
              </li>

              <!-- Paid fee -->
              <li class="f-between-center">
                <div class="text-secondary-content">Fee paid</div>
                <span>{paidFee || '-'} ETH</span>
              </li>
            </ul>
          {/if}
        </div>
      </div>
    </div>
    <div class="h-sep my-[20px]" />
    <div class="px-[24px] w-full max-h-[58px]">
      <ActionButton priority="primary" on:click={closeDetails}>{$t('common.close')}</ActionButton>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>

<StatusInfoDialog bind:modalOpen={openStatusDialog} noIcon />
