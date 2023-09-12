<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  export let modalOpen = false;

  export let noIcon = false;

  const dialogId = `dialog-${uid()}`;

  const closeModal = () => (modalOpen = false);

  const openModal = () => (modalOpen = true);

  const classes = {
    headline: 'text-center text-base font-bold leading-[24px] tracking-[0.08px] pb-[5px]',
  };

  const closeModalIfClickedOutside = (e: MouseEvent) => {
    if (e.target === e.currentTarget) {
      closeModal();
    }
  };
  const closeModalIfKeyDown = (e: KeyboardEvent) => {
    if (e.key === 'Escape') {
      closeModal();
    }
  };
</script>

<button
  aria-haspopup="dialog"
  aria-controls={dialogId}
  aria-expanded={modalOpen}
  on:click={openModal}
  on:focus={openModal}
  class=" ml-[4px]">
  {#if !noIcon}
    <Icon type="question-circle" />
  {/if}
</button>

<svelte:window on:keydown={closeModalIfKeyDown} />

<dialog id={dialogId} class="modal" class:modal-open={modalOpen}>
  <div
    class="modal-box
 bg-neutral-background text-primary-content text-center max-w-[565px]">
    <div class="w-full flex justify-end">
      <button class="right-6" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-content" size={24} />
      </button>
    </div>
    <div class="w-full">
      <h1 class="title-body-bold">{$t('activities.status.dialog.title')}</h1>
    </div>
    <div class="inline-flex flex-col space-y-9 px-[37px]">
      <br />
      {$t('activities.status.dialog.description')}
      <h4 class={classes.headline}>{$t('activities.status.initiated.name')}</h4>
      {$t('activities.status.initiated.description')}
      <h4 class={classes.headline}>{$t('activities.status.claim.name')}</h4>
      {$t('activities.status.claim.description')}
      <h4 class={classes.headline}>{$t('activities.status.claimed.name')}</h4>
      {$t('activities.status.claimed.description')}
      <h4 class={classes.headline}>{$t('activities.status.retry.name')}</h4>
      {$t('activities.status.retry.description')}
      <h4 class={classes.headline}>{$t('activities.status.release.name')}</h4>
      {$t('activities.status.release.description')}
      <h4 class={classes.headline}>{$t('activities.status.failed.name')}</h4>
      {$t('activities.status.failed.description')}
    </div>

    <!-- We catch key events aboe -->
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <div role="button" tabindex="0" class="overlay-backdrop" on:click={closeModalIfClickedOutside} />
  </div>
</dialog>
