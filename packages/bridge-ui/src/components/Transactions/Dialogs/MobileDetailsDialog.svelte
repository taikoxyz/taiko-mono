<script lang="ts">
  import { t } from 'svelte-i18n';
  import { type Address, formatEther, type Hash, hexToBigInt } from 'viem';

  import { CloseButton } from '$components/Button';
  import ActionButton from '$components/Button/ActionButton.svelte';
  import ExplorerLink from '$components/ExplorerLink/ExplorerLink.svelte';
  import { Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { bridgeTxKey } from '$libs/bridge/bridgeTxIdentity';
  import { getClaimDetails } from '$libs/bridge/getClaimDetails';
  import { isTransactionProcessable } from '$libs/bridge/isTransactionProcessable';
  import { getTransferParties } from '$libs/bridge/transferParties';
  import { getChainName, isL2Chain } from '$libs/chain';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { findClaimTxHash } from '$libs/relayer/findClaimTxHash';
  import { type NFT, TokenType } from '$libs/token';
  import { formatTimestamp } from '$libs/util/formatTimestamp';
  import { formatTokenAmount } from '$libs/util/formatTokenAmount';
  import { geBlockTimestamp } from '$libs/util/getBlockTimestamp';
  import { getLogger } from '$libs/util/logger';
  import { noop } from '$libs/util/noop';
  import { account } from '$stores/account';

  import ChainSymbolName from '../ChainSymbolName.svelte';
  import { StatusInfoDialog } from '../Status';
  import Status from '../Status/Status.svelte';
  import { claimedByRelayer } from './claimedByRelayer';

  const log = getLogger('DesktopDetailsDialog');
  const dialogId = `dialog-${crypto.randomUUID()}`;
  const placeholderUrl = '/placeholder.svg';

  export let detailsOpen = false;
  export let bridgeTx: BridgeTransaction;
  export let closeDetails = noop;

  export let token: Maybe<NFT>;

  let openStatusDialog = false;

  let tooltipOpen = false;
  const openToolTip = () => {
    tooltipOpen = !tooltipOpen;
  };

  const handleStatusDialog = () => {
    openStatusDialog = !openStatusDialog;
  };

  let initiatedAt = '';

  const getInitiatedDate = async () => {
    if (!bridgeTx.blockNumber) return;
    const blockTimestamp = await geBlockTimestamp(bridgeTx.srcChainId, hexToBigInt(bridgeTx.blockNumber));
    initiatedAt = formatTimestamp(Number(blockTimestamp));
  };

  // The relayer API reports neither claimer nor claim transaction for the messages the relayer
  // claimed itself. Its status rows still carry the transaction, filed under the message's
  // sender, and the transaction answers who and when in one read. Only once the dialog is
  // open, since every row mounts both dialogs, and only once per message. What is resolved
  // is tied to the message it was resolved for, and only the newest read may publish: an
  // older one landing late, or failing late, changes nothing
  let claimGeneration = 0;
  let claimReadFor: Maybe<string> = null;
  let resolvedFor: Maybe<string> = null;
  let resolvedClaimTxHash: Maybe<Hash> = null;
  let resolvedClaimer: Maybe<Address> = null;
  let resolvedClaimedAt = '';

  $: identity = bridgeTxKey(bridgeTx);

  const readClaim = async () => {
    const { destChainId, msgHash, message } = bridgeTx;
    // A row that arrived with its claim transaction is read as it is; one without is looked
    // up once the message is claimed
    const known = bridgeTx.destTxHash;
    if (!known && effectiveStatus !== MessageStatus.DONE) return;
    const wanted = known ?? msgHash;
    if (!destChainId || !wanted) return;
    const key = `${identity}/${wanted}`;
    if (claimReadFor === key) return;
    const generation = ++claimGeneration;
    claimReadFor = key;
    if (resolvedFor !== identity) {
      resolvedFor = null;
      resolvedClaimTxHash = null;
      resolvedClaimer = null;
      resolvedClaimedAt = '';
    }
    try {
      let claimTxHash = known;
      if (!claimTxHash) {
        const sender = message?.srcOwner ?? bridgeTx.from;
        if (!sender || !msgHash) return;
        claimTxHash = await findClaimTxHash(sender, msgHash);
        if (generation !== claimGeneration) return;
        if (!claimTxHash) {
          // Nothing to show yet; the next opening asks again
          claimReadFor = null;
          return;
        }
        resolvedFor = identity;
        resolvedClaimTxHash = claimTxHash;
      }
      const { claimedBy: claimer, claimedAt: timestamp } = await getClaimDetails(claimTxHash, destChainId);
      if (generation !== claimGeneration) return;
      resolvedFor = identity;
      resolvedClaimer = claimer;
      resolvedClaimedAt = formatTimestamp(Number(timestamp));
    } catch (error) {
      if (generation !== claimGeneration) return;
      claimReadFor = null;
      log('Could not read the claim', error);
    }
  };

  // Locally stored transactions only set msgStatus; relayer-derived ones set both
  $: effectiveStatus = bridgeTx.msgStatus ?? bridgeTx.status;

  const checkStatus = async () => {
    const isProcessable = await isTransactionProcessable(bridgeTx);
    if (effectiveStatus === MessageStatus.NEW || effectiveStatus === MessageStatus.RETRIABLE) {
      if (!isProcessable) {
        stillProcessing = true;
      } else {
        stillProcessing = false;
      }
    } else if (
      effectiveStatus === MessageStatus.DONE ||
      effectiveStatus === MessageStatus.FAILED ||
      effectiveStatus === MessageStatus.RECALLED
    ) {
      stillProcessing = false;
    }
  };

  // Only while the dialog is actually open: every row mounts both this dialog and its
  // mobile/desktop twin, so an unconditional read here cost three processability lookups
  // per row on the page whose RPC load the batching change set out to cut
  $: if (detailsOpen && $account.isConnected) checkStatus();
  $: stillProcessing = true;

  // The user's addresses, not the envelope's: a token transfer runs from vault to vault
  $: parties = getTransferParties(bridgeTx);
  $: from = parties.sender;
  $: to = parties.recipient;

  $: srcTxHash = bridgeTx.srcTxHash || null;
  $: destTxHash = bridgeTx.destTxHash || (resolvedFor === identity ? resolvedClaimTxHash : null) || null;

  $: srcChainId = bridgeTx.srcChainId || null;
  $: destChainId = bridgeTx.destChainId || null;
  $: destOwner = bridgeTx.message?.destOwner || null;

  $: if (detailsOpen && bridgeTx) readClaim();
  $: bridgeTx && getInitiatedDate();

  $: claimedBy = bridgeTx.claimedBy || (resolvedFor === identity ? resolvedClaimer : null) || null;
  $: claimedAt = resolvedFor === identity ? resolvedClaimedAt : '';
  $: isRelayer = claimedByRelayer({ claimedBy, to, destOwner, status: effectiveStatus });

  $: paidFee = formatEther(bridgeTx.fee ? bridgeTx.fee : BigInt(0));

  $: isBridgeToL1 = !isL2Chain(Number(bridgeTx.destChainId));

  $: imgUrl = token?.metadata?.image || placeholderUrl;

  $: hasAmount = bridgeTx.tokenType !== TokenType.ERC721;

  $: title =
    token && token.name && token.tokenId ? `${token.name} #${token.tokenId}` : $t('transactions.details_dialog.title');
</script>

<dialog
  use:closeOnEscapeOrOutsideClick={{ enabled: detailsOpen, callback: closeDetails, uuid: dialogId }}
  id={dialogId}
  class="modal h-full min-h-[100%]"
  class:modal-open={detailsOpen}>
  <div
    class="modal-box max-w-[100%] min-h-[100%] relative f-col justify-between w-full h-full rounded-[0px] bg-neutral-background !p-0 !pb-[20px]">
    <div class="w-dvw fixed pt-[20px] px-[24px] z-40 bg-neutral-background">
      <CloseButton onClick={closeDetails} />
      <h3 class="font-bold">{title}</h3>
      <div class="h-sep mx-[-24px] mb-0" />
    </div>
    <div class="w-full py-[50px] px-[24px] overflow-y-auto flex-grow relative">
      <div class="w-full my-[50px] text-left">
        {#if bridgeTx}
          {#if token}
            <div class="f-row items-center justify-center mb-[30px]">
              <img src={imgUrl} alt={token && token.name ? token.name : 'nft'} class="size-[150px] rounded-[20px]" />
            </div>
          {/if}
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
                    <span class="text-secondary-content">{isBridgeToL1 ? $t('bridge.alerts.slow_bridging') : ''}</span>
                  </div>

                  <div class="f-col">
                    <span
                      class="bg-neutral-background absolute size-[15px] flex items-center justify-center left-[17.5px] mt-2">
                      <Icon type="circle" fillClass="fill-primary-border-dark " class="size-[10px]" />
                    </span>
                    <span class="font-bold"
                      >Receiving {bridgeTx.symbol} on {getChainName(Number(bridgeTx.destChainId))}</span>
                  </div>
                </div>
              </div>
            {:else}
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
                  <Status bridgeTxStatus={effectiveStatus} {bridgeTx} textOnly />
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

              <!-- Token standard -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('common.token_standard')}</div>
                <span>{bridgeTx.tokenType} </span>
              </li>

              <!-- Amount -->
              {#if hasAmount}
                <li class="f-between-center">
                  <div class="text-secondary-content">{$t('common.amount')}</div>
                  {#if bridgeTx.tokenType === TokenType.ERC1155}
                    <span>{bridgeTx.amount} </span>
                  {:else}
                    <span>{formatTokenAmount(bridgeTx.amount, bridgeTx.decimals)} {bridgeTx.symbol}</span>
                  {/if}
                </li>
              {/if}
              <!-- Date initiated -->
              <li class="f-between-center">
                <div class="text-secondary-content">{$t('transactions.details_dialog.initiated_date')}</div>
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
            {/if}
          </ul>
        {/if}
      </div>
    </div>
    <div class="fixed bottom-[20px] left-0 w-full bg-neutral-background">
      <div class="h-sep mb-[20px] mt-0" />
      <div class="px-[24px] w-full max-h-[56px]">
        <ActionButton priority="primary" on:click={closeDetails}>{$t('common.close')}</ActionButton>
      </div>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>

<StatusInfoDialog bind:modalOpen={openStatusDialog} noIcon />
