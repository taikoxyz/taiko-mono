<script lang="ts">
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { bridgeTransactionPoller } from '$config';
  import { getFinalRetryState, type RecallState } from '$libs/bridge/recall';
  import type { BridgeTransaction } from '$libs/bridge/types';

  import { selectedRetryMethod } from '../state';
  import { RETRY_OPTION } from '../types';

  export let canContinue = false;
  export let bridgeTx: BridgeTransaction;
  let recallState: RecallState | 'loading' = 'loading';
  let readId = 0;
  let timer: ReturnType<typeof setInterval>;

  async function refresh(srcChainId: bigint, destChainId: bigint, background = false) {
    const currentRead = ++readId;
    const state = await getFinalRetryState({ srcChainId, destChainId });
    if (currentRead !== readId) return;
    if (!(background && state === 'unknown' && (recallState === 'enabled' || recallState === 'disabled'))) {
      recallState = state;
    }
  }

  $: recallSourceChainId = bridgeTx.srcChainId;
  $: recallDestinationChainId = bridgeTx.destChainId;
  $: {
    recallState = 'loading';
    void refresh(recallSourceChainId, recallDestinationChainId);
  }
  onMount(() => {
    timer = setInterval(
      () => void refresh(recallSourceChainId, recallDestinationChainId, true),
      bridgeTransactionPoller.interval,
    );
  });
  onDestroy(() => {
    ++readId;
    clearInterval(timer);
  });

  // Returning from Review rechecks capability without changing the user's choice.
  // An unavailable final retry requires an explicit choice of the ordinary retry.
  $: canContinue =
    $selectedRetryMethod === RETRY_OPTION.CONTINUE ||
    ($selectedRetryMethod === RETRY_OPTION.RETRY_ONCE && recallState === 'enabled');
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.pre_check.title')}</div>
  </div>
  <p>
    {$t(
      recallState === 'loading'
        ? 'transactions.status.checking_recall'
        : recallState === 'enabled'
          ? 'transactions.retry.options_description'
          : `transactions.retry.recall_${recallState}`,
    )}
  </p>

  <div class="font-bold text-primary-content">{$t('transactions.retry.select_option')}</div>
  <div class="space-y-4">
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="">{$t('transactions.retry.continue')}</span>
        <input
          type="radio"
          class="radio radio-primary-brand checked:bg-primary-brand"
          value={RETRY_OPTION.CONTINUE}
          bind:group={$selectedRetryMethod} />
      </label>
    </div>
    {#if recallState === 'enabled' || $selectedRetryMethod === RETRY_OPTION.RETRY_ONCE}
      <div class="form-control">
        <label class="label cursor-pointer">
          <span class="">{$t('transactions.retry.final_attempt')}</span>
          <input
            type="radio"
            class="radio radio-primary-brand checked:bg-primary-brand"
            value={RETRY_OPTION.RETRY_ONCE}
            disabled={recallState !== 'enabled'}
            bind:group={$selectedRetryMethod} />
        </label>
      </div>
    {/if}
  </div>
</div>
