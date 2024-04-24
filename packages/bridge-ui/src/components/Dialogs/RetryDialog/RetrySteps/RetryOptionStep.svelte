<script lang="ts">
  import { t } from 'svelte-i18n';

  import { selectedRetryMethod } from '../state';
  import { RETRY_OPTION } from '../types';

  export let canContinue = false;

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
    Your transaction has failed on chain. This could have several reasons. You can now retry as often as you want or
    only retry once more, then get the option to release the funds back on the original chain.
  </p>

  <div class="font-bold text-primary-content">Please select your preferred option:</div>
  <div class="space-y-4">
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="">Retry and keep retrying</span>
        <input
          type="radio"
          class="radio radio-primary-brand checked:bg-primary-brand"
          value={RETRY_OPTION.CONTINUE}
          checked
          bind:group={$selectedRetryMethod} />
      </label>
    </div>
    <div class="form-control">
      <label class="label cursor-pointer">
        <span class="">Retry one final time</span>
        <input
          type="radio"
          class="radio radio-primary-brand checked:bg-primary-brand"
          value={RETRY_OPTION.RETRY_ONCE}
          checked
          bind:group={$selectedRetryMethod} />
      </label>
    </div>
  </div>
</div>
