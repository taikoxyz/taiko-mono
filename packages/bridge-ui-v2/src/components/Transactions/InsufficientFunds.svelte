<script lang="ts">
  import { t } from 'svelte-i18n';

  import { ActionButton, CloseButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { PUBLIC_GUIDE_URL } from '$env/static/public';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { uid } from '$libs/util/uid';

  export let modalOpen = false;

  let dialogId = `dialog-${uid()}`;

  function closeModal() {
    modalOpen = false;
  }
</script>

<dialog
  id={dialogId}
  class="modal"
  class:modal-open={modalOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: modalOpen, callback: () => (modalOpen = false), uuid: dialogId }}>
  <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
    <CloseButton onClick={closeModal} />
    <div class="w-full space-y-6">
      <h3 class="title-body-bold mb-7">{$t('transactions.actions.claim.dialog.title')}</h3>
      <div class="body-regular text-secondary-content mb-3 flex flex-col items-end">
        <div>
          {$t('transactions.actions.claim.dialog.description')}
        </div>
      </div>

      <ActionButton priority="primary" on:click={closeModal}>
        <span class="body-bold">{$t('common.ok')}</span>
      </ActionButton>
      <div class="flex justify-center">
        <a href={PUBLIC_GUIDE_URL} target="_blank" class="flex link py-[10px]">
          {$t('transactions.actions.claim.dialog.link')}<Icon type="arrow-top-right" />
        </a>
      </div>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>
