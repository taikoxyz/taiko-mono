<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';

  import { type BridgeTransaction, isTransactionRecallEnabled } from '$libs/bridge';

  import { selectedRetryMethod } from '../state';
  import { RETRY_OPTION } from '../types';

  export let canContinue = false;
  export let bridgeTx: BridgeTransaction;

  let recallEnabled = false;

  onMount(async () => {
    recallEnabled = await isTransactionRecallEnabled(bridgeTx, 'destination');
  });

  $: if (!recallEnabled && $selectedRetryMethod === RETRY_OPTION.RETRY_ONCE) {
    $selectedRetryMethod = RETRY_OPTION.CONTINUE;
  }

  $: if (selectedRetryMethod !== undefined && selectedRetryMethod !== null) {
    canContinue = true;
  } else {
    canContinue = false;
  }
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.pre_check.title')}</div>
  </div>
  <p>
    {$t(
      recallEnabled
        ? 'transactions.retry.options.description'
        : 'transactions.retry.options.recall_disabled_description',
    )}
  </p>

  <div class="font-bold text-primary-content">{$t('transactions.retry.options.prompt')}</div>
  <div class="space-y-4">
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="">{$t('transactions.retry.options.continue')}</span>
        <input
          type="radio"
          class="radio radio-primary-brand checked:bg-primary-brand"
          value={RETRY_OPTION.CONTINUE}
          checked
          bind:group={$selectedRetryMethod} />
      </label>
    </div>
    {#if recallEnabled}
      <div class="form-control">
        <label class="label cursor-pointer">
          <span class="">{$t('transactions.retry.options.final')}</span>
          <input
            type="radio"
            class="radio radio-primary-brand checked:bg-primary-brand"
            value={RETRY_OPTION.RETRY_ONCE}
            checked
            bind:group={$selectedRetryMethod} />
        </label>
      </div>
    {/if}
  </div>
</div>
