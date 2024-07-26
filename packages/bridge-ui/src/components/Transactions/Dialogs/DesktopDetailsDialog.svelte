<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther, hexToBigInt } from 'viem';

  import { CloseButton } from '$components/Button';
  import ExplorerLink from '$components/ExplorerLink/ExplorerLink.svelte';
  import type { BridgeTransaction } from '$libs/bridge';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { formatTimestamp } from '$libs/util/formatTimestamp';
  import { getBlockFromTxHash } from '$libs/util/getBlockFromTxHash';
  import { geBlockTimestamp } from '$libs/util/getBlockTimestamp';
  import { getLogger } from '$libs/util/logger';
  // import type { NFT } from '$libs/token';
  import { noop } from '$libs/util/noop';

  import ChainSymbolName from '../ChainSymbolName.svelte';
  import { Status } from '../Status';

  const log = getLogger('DesktopDetailsDialog');

  const dialogId = `dialog-${crypto.randomUUID()}`;

  export let detailsOpen = false;
  // export let token: NFT;
  export let selectedItem: BridgeTransaction;

  export let closeDetails = noop;

  // const reset = () => {
  //   from = null;
  //   to = null;
  //   srcTxHash = '0x';
  //   destTxHash = '0x';
  //   srcChainId = null;
  //   destChainId = null;
  //   destOwner = null;
  //   initiatedAt = '';
  //   claimedAt = '';
  //   claimedBy = null;
  //   isRelayer = false;
  // };

  $: from = selectedItem.message?.from || null;
  $: to = selectedItem.message?.to || null;

  $: srcTxHash = selectedItem.srcTxHash || null;
  $: destTxHash = selectedItem.destTxHash || null;

  $: srcChainId = selectedItem.srcChainId || null;
  $: destChainId = selectedItem.destChainId || null;
  $: destOwner = selectedItem.message?.destOwner || null;

  $: selectedItem && getClaimedDate();
  $: selectedItem && getInitiatedDate();

  $: claimedBy = selectedItem.claimedBy || null;
  $: isRelayer = false;

  $: if (claimedBy !== to && claimedBy !== destOwner) {
    isRelayer = true;
  } else {
    isRelayer = false;
  }

  $: paidFee = formatEther(selectedItem.fee ? selectedItem.fee : BigInt(0));

  // $: !detailsOpen && reset();

  let initiatedAt = '';
  let claimedAt = '';

  const getInitiatedDate = async () => {
    const blockTimestamp = await geBlockTimestamp(selectedItem.srcChainId, hexToBigInt(selectedItem.blockNumber));
    initiatedAt = formatTimestamp(Number(blockTimestamp));
  };

  const getClaimedDate = async () => {
    log('destTxHash', selectedItem.destTxHash, 'destChainId', selectedItem.destChainId);
    try {
      const blockNumber = await getBlockFromTxHash(selectedItem.destTxHash, selectedItem.destChainId);
      log('blockNumber', blockNumber);
      const blockTimestamp = await geBlockTimestamp(selectedItem.destChainId, blockNumber);
      log('blockTimestamp', blockTimestamp);
      claimedAt = formatTimestamp(Number(blockTimestamp));
      log('claimedAt', claimedAt);
    } catch (error) {
      log('error', error);
    }
  };
</script>

<dialog
  id={dialogId}
  class="modal"
  class:modal-open={detailsOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: detailsOpen, callback: () => closeDetails, uuid: dialogId }}>
  <div class="modal-box relative w-full bg-neutral-background !p-0 !pb-[20px]">
    <div class="w-full pt-[35px] px-[24px]">
      <CloseButton onClick={closeDetails} />
      <h3 class="font-bold">{$t('transactions.details_dialog.title')}</h3>
    </div>
    <div class="h-sep !my-[20px]" />
    <div class="flex-col px-[24px] w-full">
      <!-- From -->
      <div class="flex justify-between space-y-[8px]">
        <div class="text-secondary-content">Transfer from</div>
        <div class="f-col">
          {#if srcChainId}
            <ChainSymbolName chainId={srcChainId} />
          {:else}
            -
          {/if}
        </div>
      </div>
      <div class="flex justify-between space-y-[8px]">
        <div class="text-secondary-content">Tx hash</div>
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
      </div>

      <!-- Spacer -->
      <div class="h-[24px]" />

      <!-- To -->
      <div class="flex justify-between">
        <div class="text-secondary-content">Transfer to</div>
        <div class="f-col">
          {#if destChainId}
            <ChainSymbolName chainId={destChainId} />
          {:else}
            -
          {/if}
        </div>
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Tx hash</div>
        <span>
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
        </span>
      </div>
    </div>

    <div class="h-sep !my-[20px]" />

    <div class="flex-col px-[24px] w-full space-y-[8px]">
      <!-- From -->
      <div class="flex justify-between">
        <div class="text-secondary-content">Status</div>
        <Status bridgeTxStatus={selectedItem.status} bridgeTx={selectedItem} textOnly />
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Sender address</div>
        {#if from}
          <div><ExplorerLink category="address" urlParam={from} chainId={Number(srcChainId)} shorten /></div>
        {/if}
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Recipient address</div>
        {#if to}
          <div><ExplorerLink category="address" urlParam={to} chainId={Number(destChainId)} shorten /></div>
        {/if}
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Destination owner</div>
        {#if destOwner}
          <div><ExplorerLink category="address" urlParam={destOwner} chainId={Number(destChainId)} shorten /></div>
        {/if}
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Amount</div>
        <span>{formatEther(selectedItem.amount ? selectedItem.amount : BigInt(0))} {selectedItem.symbol}</span>
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Date initiated</div>
        <div>{initiatedAt}</div>
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Claimed by</div>
        <div>
          {#if isRelayer}
            <span>Relayer</span>
          {:else if claimedBy}
            <ExplorerLink category="address" urlParam={claimedBy} chainId={Number(destChainId)} shorten />
          {:else}
            -
          {/if}
        </div>
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Claim date</div>
        <div>{claimedAt}</div>
      </div>

      <div class="flex justify-between">
        <div class="text-secondary-content">Fee paid</div>
        <span>{paidFee} ETH</span>
      </div>
    </div>
  </div>
  <button class="overlay-backdrop" on:click={closeDetails} />
</dialog>
