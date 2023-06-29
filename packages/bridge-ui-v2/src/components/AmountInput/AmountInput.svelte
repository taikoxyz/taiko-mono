<script lang="ts">
  import { t } from 'svelte-i18n';

  import { InputBox } from '$components/InputBox';
  import { uid } from '$libs/util/uid';

  let inputId = `input-${uid()}`;
</script>

<div class="f-col space-y-2">
  <div class="f-between-center text-secondary-content body-regular">
    <label for={inputId}>{$t('amount_input.label')}</label>
    <div>
      <span>{$t('amount_input.balance')}:</span>
      <span>399.92 ETH</span>
    </div>
  </div>
  <div class="relative f-items-center">
    <InputBox
      id={inputId}
      type="number"
      placeholder="0.01"
      min="0"
      class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
    <button class="absolute right-6 uppercase">{$t('amount_input.max_button')}</button>
  </div>
</div>
