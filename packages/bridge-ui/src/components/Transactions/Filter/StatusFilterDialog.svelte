<script lang="ts">
  import { t } from 'svelte-i18n';

  import { ActionButton, CloseButton } from '$components/Button';
  import { MessageStatus } from '$libs/bridge';
  import { uid } from '$libs/util/uid';

  export let selectedStatus: MessageStatus | null = null;

  let dialogId = `dialog-${uid()}`;

  export let menuOpen = false;

  const closeMenu = () => {
    menuOpen = false;
  };

  const options = [
    { value: null, label: $t('transactions.filter.all') },
    { value: MessageStatus.NEW, label: $t('transactions.filter.processing') },
    { value: MessageStatus.RETRIABLE, label: $t('transactions.filter.retry') },
    { value: MessageStatus.DONE, label: $t('transactions.filter.claimed') },
    { value: MessageStatus.FAILED, label: $t('transactions.filter.failed') },
  ];

  const select = (option: (typeof options)[0]) => {
    selectedStatus = option.value;
  };
</script>

<dialog id={dialogId} class="modal modal-bottom" class:modal-open={menuOpen}>
  <div class="modal-box relative w-full bg-neutral-background !p-0">
    <div class="w-full pt-[35px] px-[24px]">
      <CloseButton onClick={closeMenu} />
      <h3 class="font-bold">{$t('transactions.filter.title')}</h3>
    </div>
    <div class="h-sep my-[20px]" />
    <div class="w-full px-[24px] text-left">
      <h3 class="font-bold text-left">{$t('common.status')}</h3>
      <div class="flex flex-wrap justify-center gap-[9px] mt-[16px]">
        {#each options as option (option.value)}
          <ActionButton
            priority={option.value === selectedStatus ? 'primary' : 'secondary'}
            class="!max-h-[36px] btn-sm !px-[20px] !py-[8px]"
            on:click={() => select(option)}
            on:keydown={() => select(option)}>{option.label}</ActionButton>
        {/each}
      </div>
    </div>
    <div class="h-sep mt-[20px] mb-0" />
    <div class="w-full px-[24px] my-[20px]">
      <ActionButton priority="primary" on:click={closeMenu}>{$t('common.see_results')}</ActionButton>
    </div>
  </div>
  <button class="overlay-backdrop" on:click={closeMenu} />
</dialog>
