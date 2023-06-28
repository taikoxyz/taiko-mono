<script>
  import { t } from 'svelte-i18n';

  import { InputBox } from '$components/InputBox';
  import { Icon } from '$components/Icon';
</script>

<div class="relative flex items-center">
  <InputBox
    class="w-full input-box outline-none py-3 px-6 pr-[52px] body-regular placeholder:text-tertiary-content"
    pattern="^0x[a-fA-F0-9]{40}$"
    placeholder={$t('custom_recipient.placeholder')} />
  <button class="absolute right-6">
    <Icon type="question-circle" />
  </button>
</div>
