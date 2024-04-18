<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ClaimDialog, ReleaseDialog, RetryDialog } from '$components/Dialogs';
  import { Spinner } from '$components/Spinner';
  import { StatusDot } from '$components/StatusDot';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { getMessageStatusForMsgHash } from '$libs/bridge/getMessageStatusForMsgHash';
  import { isTransactionProcessable } from '$libs/bridge/isTransactionProcessable';
  import { BridgePausedError } from '$libs/error';
  import { PollingEvent, startPolling } from '$libs/polling/messageStatusPoller';
  import type { NFT } from '$libs/token';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';

  export let bridgeTx: BridgeTransaction;
  export let nft: NFT | null = null;

  let polling: ReturnType<typeof startPolling>;

  // UI state
  let isProcessable = false; // bridge tx state to be processed: claimed/retried/released
  let bridgeTxStatus: Maybe<MessageStatus>;

  let loading = false;

  function onProcessable(isTxProcessable: boolean) {
    isProcessable = isTxProcessable;
  }

  async function claimingDone() {
    // Keeping model and UI in sync
    bridgeTx.msgStatus = await getMessageStatusForMsgHash({
      msgHash: bridgeTx.msgHash,
      srcChainId: Number(bridgeTx.srcChainId),
      destChainId: Number(bridgeTx.destChainId),
    });
    bridgeTxStatus = bridgeTx.msgStatus;
  }

  function onStatusChange(status: MessageStatus) {
    // Keeping model and UI in sync
    bridgeTxStatus = bridgeTx.msgStatus = status;
  }

  async function handleRetryClick() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    if (!$connectedSourceChain || !$account?.address) return;
    retryModalOpen = true;
  }

  async function handleReleaseClick() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    if (!$connectedSourceChain || !$account?.address) return;
    releaseModalOpen = true;
  }

  async function handleClaimClick() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    if (!$connectedSourceChain || !$account?.address) return;

    claimModalOpen = true;
  }

  async function release() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    if (!$connectedSourceChain || !$account?.address) return;
    // TODO: implement release handling
  }

  $: claimModalOpen = false;
  $: retryModalOpen = false;
  $: releaseModalOpen = false;

  onMount(async () => {
    if (bridgeTx && $account?.address) {
      bridgeTxStatus = bridgeTx.msgStatus;

      // Can we start claiming/retrying/releasing?
      isProcessable = await isTransactionProcessable(bridgeTx);

      try {
        polling = startPolling(bridgeTx);

        // If there is no emitter, means the bridgeTx is already DONE
        // so we do nothing here
        if (polling?.emitter) {
          // The following listeners will trigger change in the UI
          polling.emitter.on(PollingEvent.PROCESSABLE, onProcessable);
          polling.emitter.on(PollingEvent.STATUS, onStatusChange);
        }
      } catch (err) {
        console.error(err);
        // TODO: handle error
      }
    }
  });

  onDestroy(() => {
    if (polling) {
      polling.destroy();
    }
  });
</script>

<div class="Status f-items-center space-x-1">
  {#if !isProcessable}
    <StatusDot type="pending" />
    <span>{$t('transactions.status.processing.name')}</span>
  {:else if loading}
    <div class="f-items-center space-x-2">
      <Spinner />
      <span>{$t(`transactions.status.${loading}`)}</span>
    </div>
  {:else if bridgeTxStatus === MessageStatus.NEW}
    <button class="status-btn" on:click={handleClaimClick}>
      {$t('transactions.button.claim')}
    </button>
  {:else if bridgeTxStatus === MessageStatus.RETRIABLE}
    <button class="status-btn" on:click={handleRetryClick}>
      {$t('transactions.button.retry')}
    </button>
  {:else if bridgeTxStatus === MessageStatus.DONE}
    <StatusDot type="success" />
    <span>{$t('transactions.status.claimed.name')}</span>
  {:else if bridgeTxStatus === MessageStatus.FAILED}
    <button class="status-btn" on:click={release} on:click={handleReleaseClick}>
      {$t('transactions.button.release')}
    </button>
  {:else}
    <!-- TODO: look into this possible state -->
    <StatusDot type="error" />
    <span>{$t('transactions.status.error.name')}</span>
  {/if}
</div>

<RetryDialog {bridgeTx} bind:dialogOpen={retryModalOpen} />

<ReleaseDialog {bridgeTx} bind:dialogOpen={releaseModalOpen} />

<ClaimDialog {bridgeTx} bind:loading bind:dialogOpen={claimModalOpen} {nft} on:claimingDone={() => claimingDone()} />
