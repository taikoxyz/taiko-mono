<script lang="ts">
  import { createEventDispatcher, onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Spinner } from '$components/Spinner';
  import { StatusDot } from '$components/StatusDot';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { isTransactionProcessable } from '$libs/bridge/isTransactionProcessable';
  import { BridgePausedError } from '$libs/error';
  import { PollingEvent, startPolling } from '$libs/polling/messageStatusPoller';
  import { bridgeTxService } from '$libs/storage';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';

  const dispatch = createEventDispatcher();

  export let bridgeTx: BridgeTransaction;
  export let bridgeTxStatus: Maybe<MessageStatus>;

  // UI state
  let isProcessable = false; // bridge tx state to be processed: claimed/retried/released
  let polling: ReturnType<typeof startPolling>;
  let loading = false;
  let hasError = false;

  function onProcessable(isTxProcessable: boolean) {
    isProcessable = isTxProcessable;
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
    // retryModalOpen = true;
    dispatch('openModal', 'retry');
  }

  async function handleReleaseClick() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    if (!$connectedSourceChain || !$account?.address) return;
    // releaseModalOpen = true;
    dispatch('openModal', 'release');
  }

  async function handleClaimClick() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    if (!$connectedSourceChain || !$account?.address) return;

    // claimModalOpen = true;
    dispatch('openModal', 'claim');
  }

  async function release() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });
    if (!$connectedSourceChain || !$account?.address) return;
    // TODO: implement release handling
  }

  $: if (hasError && $account.address) {
    if (bridgeTxService.transactionIsStoredLocally($account.address, bridgeTx)) {
      // If we can't start polling, it maybe an old/outdated transaction in the local storage, so we remove it
      bridgeTxService.removeTransactions($account.address, [bridgeTx]);
      if (!bridgeTxService.transactionIsStoredLocally($account.address, bridgeTx)) {
        dispatch('transactionRemoved', bridgeTx);
      }
    }
  }

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
        console.warn('Cannot start polling', err);
        hasError = true;
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
  {:else if bridgeTxStatus === MessageStatus.RECALLED}
    <StatusDot type="error" />
    <span>{$t('transactions.status.released.name')}</span>
  {:else}
    <!-- TODO: look into this possible state -->
    <StatusDot type="error" />
    <span>{$t('transactions.status.error.name')}</span>
  {/if}
</div>
