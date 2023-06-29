<script>
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { Tooltip } from '$components/Tooltip';
  import { uid } from '$libs/util/uid';

  let dialogId = `dialog-${uid()}`;
  let selectedFee;
  let modalOpen = false;

  function closeModal() {
    modalOpen = false;
  }

  function openModal() {
    modalOpen = true;
  }
</script>

<div id="ProcessingFee">
  <div class="flex-between-center">
    <div class="flex space-x-2">
      <span class="body-small-regular text-secondary-content">{$t('processing_fee.title')}</span>
      <Tooltip>TODO: add description about processing fee</Tooltip>
    </div>
    <button
      class="link-regular text-primary-link underline hover:text-primary-link-hover"
      on:click={openModal}
      on:focus={openModal}>{$t('processing_fee.link')}</button>
  </div>

  <dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[30px] bg-neutral-background">
      <button class="absolute right-6 top-[30px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-icon" />
      </button>
      <h3 class="title-body-bold mb-7">{$t('processing_fee.title')}</h3>
      <ul class="space-y-7">
        <li class="flex-between-center">
          <div class="flex flex-col">
            <label for="recommended-fee" class="body-bold">{$t('processing_fee.recommended')}</label>
            <span class="body-small-regular text-secondary-content">0.0001350000 ETH</span>
          </div>
          <input
            id="recommended-fee"
            class="radio w-6 h-6 checked:bg-primary-interactive-accent"
            type="radio"
            name="processing_fee"
            value="recommended" />
        </li>
        <li class="flex-between-center">
          <div class="flex flex-col">
            <label for="none-fee" class="body-bold">{$t('processing_fee.none.label')}</label>
            <span class="body-small-regular text-secondary-content">{$t('processing_fee.none.text')}</span>
          </div>
          <input
            id="none-fee"
            type="radio"
            class="radio w-6 h-6 checked:bg-primary-interactive-accent"
            name="processing_fee"
            value="none" />
        </li>
        <li class="flex-between-center">
          <div class="flex flex-col">
            <label for="custom-fee" class="body-bold">{$t('processing_fee.custom.label')}</label>
            <span class="body-small-regular text-secondary-content">{$t('processing_fee.custom.text')}</span>
          </div>
          <input
            id="custom-fee"
            type="radio"
            class="radio w-6 h-6 checked:bg-primary-interactive-accent"
            name="processing_fee"
            value="custom" />
        </li>
      </ul>
      <div class="modal-backdrop bg-overlay-background" />
    </div>
  </dialog>
</div>
