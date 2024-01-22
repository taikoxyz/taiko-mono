<script lang="ts">
  import { t } from 'svelte-i18n';

  import { selectedToken } from '$components/Bridge/state';
  import { InputBox } from '$components/InputBox';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { tokens } from '$libs/token';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';

  const log = getLogger('TokenInput');

  let inputId = `input-${uid()}`;
  let inputBox: InputBox;

  let amountDisabled = false;
  let tokenDisabled = false;

  const inputAmount = () => {
    log('inputAmount', inputBox.value);
  };

  const useMaxAmount = () => {
    log('useMaxAmount');
  };

  $: invalidInput = false;
</script>

<div class="relative f-row h-[80px]">
  <div class="relative f-items-center">
    <InputBox
      id={inputId}
      type="number"
      placeholder="0.01"
      min="0"
      disabled={amountDisabled}
      error={invalidInput}
      on:input={inputAmount}
      bind:this={inputBox}
      class="py-6 pl-[26px] w-full title-subsection-bold border-0 h-full !rounded-r-none z-20  {$$props.class}" />

    <div class="border-l border-primary-border-dark h-[80px] w-[2px]" />

    <button class="absolute right-6 uppercase hover:font-bold z-20" on:click={useMaxAmount}>
      {$t('inputs.amount.button.max')}
    </button>
  </div>
  <TokenDropdown
    class="max-w-[151px] min-w-[151px] z-20"
    {tokens}
    bind:value={$selectedToken}
    bind:disabled={tokenDisabled} />
</div>
