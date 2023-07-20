<script lang="ts">
  import { t } from 'svelte-i18n';

  import { InputBox } from '$components/InputBox';
  import { Tooltip } from '$components/Tooltip';
  import { Button } from '$components/Button';
  import { uid } from '$libs/util/uid';
  import { Icon } from '$components/Icon';
  import { account } from '$stores/account';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { onMount } from 'svelte';
  import { recipientAddress } from '../state';
  import { isAddress } from 'viem';

  let dialogId = `dialog-${uid()}`;

  let modalOpen = false;
  let invalidAddress = false;

  let inputBox: InputBox;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
  }

  function cancelModal() {
    inputBox.clear();
    closeModal();
  }

  function focusInputBox() {
    inputBox.focus();
  }

  function inputRecipientAddress(event: Event) {
    const { value } = event.target as HTMLInputElement;
    if (isAddress(value)) {
      invalidAddress = false;
      $recipientAddress = value;
    } else {
      invalidAddress = true;
    }
  }

  onMount(focusInputBox);
</script>

<div class="Recipient">
  <div class="f-between-center">
    <div class="flex space-x-2">
      <span class="body-small-bold text-primary-content">{$t('recipient.title')}</span>
      <Tooltip>TODO: add description about processing fee</Tooltip>
    </div>
    <button class="link" on:click={openModal} on:focus={openModal}>{$t('common.edit')}</button>
  </div>

  <span class="body-small-regular text-secondary-content mt-[6px]">
    {#if $account?.address}
      {shortenAddress($account.address, 15, 13)}
    {:else}
      {$t('recipient.placeholder')}
    {/if}
  </span>

  <dialog id={dialogId} class="modal" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
      <button class="absolute right-6 top-[35px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-icon" size={24} />
      </button>

      <h3 class="title-body-bold mb-7">{$t('recipient.title')}</h3>

      <!-- TODO -->

      <div class="relative f-items-center my-[20px]">
        <InputBox
          placeholder={$t('recipient.placeholder')}
          class="w-full input-box outline-none p-6 pr-16 title-subsection-bold placeholder:text-tertiary-content"
          on:input={inputRecipientAddress}
          bind:this={inputBox} />
      </div>

      <div class="grid grid-cols-2 gap-[20px]">
        <Button
          on:click={cancelModal}
          type="neutral"
          class="px-[28px] py-[10px] rounded-full w-auto bg-transparent !border border-primary-brand hover:border-primary-interactive-hover">
          <span class="body-bold">{$t('common.cancel')}</span>
        </Button>
        <Button type="primary" class="px-[28px] py-[10px] rounded-full w-auto" on:click={closeModal}>
          <span class="body-bold">{$t('common.confirm')}</span>
        </Button>
      </div>
    </div>
  </dialog>
</div>
