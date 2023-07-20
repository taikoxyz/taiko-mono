<script>
  import { t } from 'svelte-i18n';

  import { InputBox } from '$components/InputBox';
  import { Tooltip } from '$components/Tooltip';

  let open = false;

  function toggleRecipient() {
    open = !open;
  }
</script>

<div class="Recipient f-col space-y-2">
  <div class="f-between-center">
    <div class="flex space-x-2">
      <span class="body-small-regular text-secondary-content">Recipient address</span>
      <Tooltip>TODO: add description about custom recipient</Tooltip>
    </div>
    <button class="link" on:click={toggleRecipient}>Edit</button>
  </div>
  <div class:hidden={!open} class:animate-fade={open}>
    <InputBox
      class="w-full input-box outline-none py-3 px-6 pr-[52px] body-regular placeholder:text-tertiary-content"
      pattern="^0x[a-fA-F0-9]{40}$"
      placeholder={$t('custom_recipient.placeholder')} />
  </div>
</div>
