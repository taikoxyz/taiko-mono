<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther, hexToBigInt } from 'viem';

  import { CloseButton } from '$components/Button';
  import ExplorerLink from '$components/ExplorerLink/ExplorerLink.svelte';
  import { Icon } from '$components/Icon';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { isTransactionProcessable } from '$libs/bridge/isTransactionProcessable';
  import { getChainName } from '$libs/chain';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { type NFT, TokenType } from '$libs/token';
  import { formatTimestamp } from '$libs/util/formatTimestamp';
  import { getBlockFromTxHash } from '$libs/util/getBlockFromTxHash';
  import { geBlockTimestamp } from '$libs/util/getBlockTimestamp';
  import { getLogger } from '$libs/util/logger';
  // import type { NFT } from '$libs/token';
  import { noop } from '$libs/util/noop';
  import { account } from '$stores/account';

  import ChainSymbolName from '../ChainSymbolName.svelte';
  import { Status } from '../Status';

  const log = getLogger('DesktopDetailsDialog');
  const placeholderUrl = '/placeholder.svg';
  const dialogId = `dialog-${crypto.randomUUID()}`;

  export let detailsOpen = false;
  // export let token: NFT;
  export let bridgeTx: BridgeTransaction;
  export let token: Maybe<NFT>;
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

  const checkStatus = async () => {
    const isProcessable = await isTransactionProcessable(bridgeTx);
    if (bridgeTx.status === MessageStatus.NEW || bridgeTx.status === MessageStatus.RETRIABLE) {
      if (!isProcessable) {
        stillProcessing = true;
      } else {
        stillProcessing = false;
      }
    } else if (
      bridgeTx.status === MessageStatus.DONE ||
      bridgeTx.status === MessageStatus.FAILED ||
      bridgeTx.status === MessageStatus.RECALLED
    ) {
      stillProcessing = false;
    }
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

  $: stillProcessing = true;

  $: $account.isConnected && checkStatus();
  $: hasAmount = bridgeTx.tokenType !== TokenType.ERC721;
  $: imgUrl = token?.metadata?.image || placeholderUrl;

  // $: !detailsOpen && reset();
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
      {#if token}
        <div class="f-row items-center justify-center mb-[30px]">
          <img src={imgUrl} alt={token && token.name ? token.name : 'nft'} class="size-[150px] rounded-[20px]" />
        </div>
      {/if}
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
      {#if stillProcessing}
        <div class="f-row">
          <div class="f-col min-h-full border border-dashed border-primary-border-dark mr-[20px] my-[10px]" />
          <!-- Vertical line -->
          <div class="f-col space-y-[30px]">
            <div class="f-col relative">
              <span
                class="bg-neutral-background absolute size-[20px] flex items-center justify-center left-[-30px] mt-1">
                <Icon type="check" fillClass="fill-positive-sentiment" class="size-[16px]" />
              </span>
              <span class="font-bold">Transaction initiated</span>
              <span class="text-secondary-content">
                <ExplorerLink
                  class="text-secondary-content"
                  urlParam={srcTxHash}
                  linkText={initiatedAt}
                  category="tx"
                  chainId={Number(srcChainId)}
                  shorten /></span>
            </div>

            <div class="f-col">
              <span
                class="bg-neutral-background absolute size-[20px] flex items-center justify-center left-[15px] mt-1">
                <Spinner class="bg-positive-sentiment !loading-xs " />
              </span>

              <span class="font-bold text-positive-sentiment">Waiting for transaction to be processed</span>
              <span class="text-secondary-content">Depending on your direction, this can take up to 24hs</span>
            </div>

            <div class="f-col">
              <span
                class="bg-neutral-background absolute size-[15px] flex items-center justify-center left-[17.5px] mt-2">
                <Icon type="circle" fillClass="fill-primary-border-dark " class="size-[10px]" />
              </span>
              <span class="font-bold">Receiving {bridgeTx.symbol} on {getChainName(Number(bridgeTx.destChainId))}</span>
            </div>
          </div>
        </div>
      {:else}
        <!-- From -->
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('common.status')}</div>
          <Status bridgeTxStatus={bridgeTx.status} {bridgeTx} textOnly />
        </div>

        <!-- Sender -->
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('transactions.details_dialog.sender_address')}</div>
          {#if from}
            <div><ExplorerLink category="address" urlParam={from} chainId={Number(srcChainId)} shorten /></div>
          {/if}
        </div>

        <!-- Recipient -->
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('transactions.details_dialog.recipient_address')}</div>
          {#if to}
            <div><ExplorerLink category="address" urlParam={to} chainId={Number(destChainId)} shorten /></div>
          {/if}
        </div>

        <!-- Dest owner -->
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('transactions.details_dialog.destination_owner')}</div>
          {#if destOwner}
            <div><ExplorerLink category="address" urlParam={destOwner} chainId={Number(destChainId)} shorten /></div>
          {/if}
        </div>

        <!-- Token standard -->
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('common.token_standard')}</div>
          <span>{bridgeTx.tokenType} </span>
        </div>

        <!-- Amount -->
        {#if hasAmount}
          <div class="flex justify-between">
            <div class="text-secondary-content">{$t('common.amount')}</div>
            {#if bridgeTx.tokenType === TokenType.ERC1155}
              <span>{bridgeTx.amount} </span>
            {:else}
              <span>{formatEther(bridgeTx.amount ? bridgeTx.amount : BigInt(0))} {bridgeTx.symbol}</span>
            {/if}
          </div>
        {/if}
        <!-- Date initiated -->
        <div class="flex justify-between">
          <div class="text-secondary-content">{$t('transactions.details_dialog.initiated_date')}</div>
          <div>{initiatedAt}</div>
        </div>

        <!-- Claimed by -->
        <div class="flex justify-between">
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
        </div>

        <!-- Claim date -->
        <div class="flex justify-between">
          <div class="text-secondary-content">Claim date</div>
          <div>{claimedAt}</div>
        </div>

        <!-- Paid fee -->
        <div class="flex justify-between">
          <div class="text-secondary-content">Fee paid</div>
          <span>{paidFee} ETH</span>
        </div>
      {/if}
    </div>
  </div>
  <button class="overlay-backdrop" on:click={closeDetails} />
</dialog>
