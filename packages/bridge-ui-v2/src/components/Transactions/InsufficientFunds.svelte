<script lang="ts">
  import { onDestroy } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { CloseButton } from '$components/CloseButton';
  import { Icon } from '$components/Icon';
  import { PUBLIC_GUIDE_URL } from '$env/static/public';
  import { uid } from '$libs/util/uid';

  export let modalOpen = false;

  let dialogId = `dialog-${uid()}`;

  function closeModal() {
    removeEscKeyListener();
    modalOpen = false;
  }

  let escKeyListener: (event: KeyboardEvent) => void;

  const addEscKeyListener = () => {
    escKeyListener = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        closeModal();
      }
    };
    window.addEventListener('keydown', escKeyListener);
  };

  const removeEscKeyListener = () => {
    window.removeEventListener('keydown', escKeyListener);
  };

  onDestroy(() => {
    removeEscKeyListener();
  });

  $: if (modalOpen) {
    addEscKeyListener();
  } else {
    removeEscKeyListener();
  }
</script>

<dialog id={dialogId} class="modal" class:modal-open={modalOpen}>
  <div class="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
    <CloseButton onClick={closeModal} />
    <div class="w-full space-y-6">
      <h3 class="title-body-bold mb-7">{$t('transactions.actions.claim.dialog.title')}</h3>
      <div class="body-regular text-secondary-content mb-3 flex flex-col items-end">
        <div>
          {$t('transactions.actions.claim.dialog.description')}
        </div>
        <a href={PUBLIC_GUIDE_URL} target="_blank" class="flex link py-[10px]">
          {$t('transactions.actions.claim.dialog.link')}<Icon type="arrow-top-right" />
        </a>
      </div>

      <Button
        type="primary"
        class="px-[28px] py-[10px] rounded-full w-full border-primary-brand"
        hasBorder={true}
        on:click={closeModal}>
        <span class="body-bold">{$t('common.ok')}</span>
      </Button>
    </div>
  </div>
</dialog>
