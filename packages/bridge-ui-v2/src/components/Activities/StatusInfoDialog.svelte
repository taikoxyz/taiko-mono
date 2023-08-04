<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { uid } from '$libs/util/uid';

  let dialogId = `dialog-${uid()}`;
  let modalOpen = false;

  const closeModal = () => (modalOpen = false);

  const openModal = () => (modalOpen = true);

  const classes = {
    headline: 'font-bold mt-[20px]',
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
  <Icon type="question-circle" />
</button>

<svelte:window on:keydown={closeModalIfKeyDown} />

<dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
  <div
    class="modal-box relative px-6 py-[35px] md:py-[20px] bg-primary-base-background text-primary-base-content text-center">
    <button class="absolute right-6 top-[35px] md:top-[20px]" on:click={closeModal}>
      <Icon type="x-close" fillClass="fill-secondary-icon" size={24} />
    </button>
    <h3 class="title-body-bold mb-[20px]">{$t('activities.status.dialog.title')}</h3>

    <p>{$t('activities.status.dialog.description')}</p>
    <h4 class={classes.headline}>{$t('activities.status.initiated.name')}</h4>
    <p>
      {$t('activities.status.initiated.description')}
    </p>
    <h4 class={classes.headline}>{$t('activities.status.claim.name')}</h4>
    <p>
      {$t('activities.status.claim.description')}
    </p>
    <h4 class={classes.headline}>{$t('activities.status.claimed.name')}</h4>
    <p>
      {$t('activities.status.claimed.description')}
    </p>
    <h4 class={classes.headline}>{$t('activities.status.retry.name')}</h4>
    <p>
      {$t('activities.status.retry.description')}
    </p>
    <h4 class={classes.headline}>{$t('activities.status.release.name')}</h4>
    <p>
      {$t('activities.status.release.description')}
    </p>
    <h4 class={classes.headline}>{$t('activities.status.failed.name')}</h4>
    <p>
      {$t('activities.status.failed.description')}
    </p>
  </div>

  <!-- We catch key events aboe -->
  <!-- svelte-ignore a11y-click-events-have-key-events -->
  <div role="button" tabindex="0" class="overlay-backdrop" on:click={closeModalIfClickedOutside} />
</dialog>
