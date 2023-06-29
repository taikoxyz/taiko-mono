<script>
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

<div>
  <div class="flex justify-between items-center">
    <div class="flex space-x-2">
      <span class="body-small-regular text-secondary-content">Processing Fee</span>
      <Tooltip>TODO: add description about processing fee</Tooltip>
    </div>
    <button
      class="link-regular text-primary-link underline hover:text-primary-link-hover"
      on:click={openModal}
      on:focus={openModal}>Customise fee</button>
  </div>

  <dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
    <div class="modal-box relative px-6 py-[30px] bg-neutral-background text-secondary-content">
      <button class="absolute right-6 top-[30px]" on:click={closeModal}>
        <Icon type="x-close" fillClass="fill-primary-icon" />
      </button>
      <h3 class="title-body-bold">Processing fee</h3>
    </div>
    <div class="modal-backdrop bg-overlay-background" />
  </dialog>
</div>
