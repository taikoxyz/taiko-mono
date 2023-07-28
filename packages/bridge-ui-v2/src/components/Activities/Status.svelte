<script lang="ts">
  import type { EventEmitter } from 'events';
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { StatusDot } from '$components/StatusDot';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { PollingEvent, startPolling } from '$libs/bridge/bridgeTxMessageStatusPoller';

  export let bridgeTx: BridgeTransaction;

  let polling: ReturnType<typeof startPolling>;

  // UI state
  let processable = false;
  let bridgeTxStatus: Maybe<MessageStatus> = bridgeTx.status;

  // TODO: enum?
  let loading: 'claiming' | 'retrying' | 'releasing' | false = false;

  function onProcessable(isTxProcessable: boolean) {
    processable = isTxProcessable;
  }

  function onStatusChange(status: MessageStatus) {
    bridgeTxStatus = status;
  }

  // We need this function to update the model and UI manually
  function setBridgeTxStatus(status: MessageStatus) {
    bridgeTx.status = status;
    onStatusChange(status);
  }

  function claim() {
    loading = 'claiming';

    // Step 1: ensure correct chain. We need
    //         $network and bridgeTx.destChainId

    // Step 2: make sure the user has enough balance on
    //         the destination chain, otherwise errorToast
    //         publicClient.getBalance()

    // Step 3: Find out the type of bridge: ETHBridge, ERC20Bridge, etc..

    // Step 4: Call bridge.claim() method with the right params:
    //         try {
    //           const txHash = await bridge.claim(...)
    //           infoToast()
    //           await pendingTransactions.add(txHash, $network.id);
    //           stopPolling()
    //           setBridgeTxStatus(MessageStatus.DONE)
    //           successToast()
    //         } catch (err) {
    //           // Check type of error
    //           errorToast()
    //         }
    //         finally { loading = false; }
  }

  function retry() {
    // TODO
  }

  function release() {
    // TODO
  }

  onMount(() => {
    if (bridgeTx) {
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
  {#if !processable}
    <StatusDot type="pending" />
    <span>{$t('activities.status.initiated')}</span>
  {:else if loading}
    TODO: add loading indicator and text for 'claiming', 'retrying', 'releasing'
  {:else if bridgeTxStatus === MessageStatus.NEW}
    <button class="status-btn w-full" on:click={claim}>
      {$t('activities.button.claim')}
    </button>
  {:else if bridgeTxStatus === MessageStatus.RETRIABLE}
    <button class="status-btn w-full" on:click={retry}>
      {$t('activities.button.claim')}
    </button>
  {:else if bridgeTxStatus === MessageStatus.DONE}
    <StatusDot type="success" />
    <span>{$t('activities.status.claimed')}</span>
  {:else if bridgeTxStatus === MessageStatus.FAILED}
    <button class="status-btn w-full" on:click={release}>
      {$t('activities.button.claim')}
    </button>
  {:else}
    <StatusDot type="error" />
    <span>{$t('activities.status.error')}</span>
  {/if}
</div>
