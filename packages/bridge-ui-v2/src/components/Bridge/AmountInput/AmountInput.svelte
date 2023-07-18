<script lang="ts">
  import { t } from 'svelte-i18n';
  import { parseUnits } from 'viem';

  import { InputBox } from '$components/InputBox';
  import { uid } from '$libs/util/uid';

  import { enteredAmount, selectedToken } from '../state';
  import Balance from './Balance.svelte';

  let inputId = `input-${uid()}`;

  function updateAmount(event: Event) {
    if (!$selectedToken) return;

    const target = event.target as HTMLInputElement;

    try {
      $enteredAmount = parseUnits(target.value, $selectedToken?.decimals);
    } catch (err) {
      $enteredAmount = BigInt(0);
    }
  }
</script>

<div class="AmountInput f-col space-y-2">
  <div class="f-between-center text-secondary-content">
    <label class="body-regular" for={inputId}>{$t('amount_input.label')}</label>
    <Balance />
  </div>
  <div class="relative f-items-center">
    <InputBox
      id={inputId}
      type="number"
      placeholder="0.01"
      min="0"
      on:input={updateAmount}
      class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
    <button class="absolute right-6 uppercase">{$t('amount_input.button.max')}</button>
  </div>
</div>
