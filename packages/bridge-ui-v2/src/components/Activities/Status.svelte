<script lang="ts">
  import type { EventEmitter } from 'events';
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { StatusDot } from '$components/StatusDot';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { PollingEvent, startPolling } from '$libs/bridge/bridgeTxMessageStatusPoller';

  export let bridgeTx: BridgeTransaction;

  let emitter: Maybe<EventEmitter> = null;
  let processable = false;
  let bridgeTxStatus: Maybe<MessageStatus> = bridgeTx.status;
  let loading: 'claiming' | 'retrying' | 'releasing' | false = false;

  function onProcessable(isTxProcessable: boolean) {
    processable = isTxProcessable;
  }

  function onStatusChange(status: MessageStatus) {
    bridgeTxStatus = status;
  }

  function claim() {}

  function retry() {}

  function release() {}

  onMount(() => {
    if (bridgeTx) {
      try {
        emitter = startPolling(bridgeTx);

        if (emitter) {
          emitter.on(PollingEvent.PROCESSABLE, onProcessable);
          emitter.on(PollingEvent.STATUS, onStatusChange);
        }
      } catch (err) {
        console.error(err);
        // TODO: handle error
      }
    }
  });

  onDestroy(() => {
    if (emitter) {
      emitter.removeAllListeners();
    }
  });
</script>

<div class="Status f-items-center space-x-1">
  {#if !processable}
    <StatusDot type="pending" />
    <span>{$t('activities.status.initiated')}</span>
  {:else if loading}
    TODO: add loading indicator
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
