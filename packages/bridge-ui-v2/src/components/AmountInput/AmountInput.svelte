<script>
  import { InputBox } from '$components/InputBox';
  import { t } from 'svelte-i18n';
</script>

<div class="relative flex items-center">
  <InputBox
    type="number"
    placeholder="0.01"
    min="0"
    class="w-full input-box outline-none py-6 pr-16 px-[26px] title-subsection-bold placeholder:text-tertiary-content" />
  <button class="absolute right-6 uppercase">{$t('amount_input.max_button')}</button>
</div>
