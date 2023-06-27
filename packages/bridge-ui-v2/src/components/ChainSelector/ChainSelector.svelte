<script>
  import { t } from 'svelte-i18n';

  import { EthIcon } from '$components/Icon';

  let modalOpen = false;

  function openModal() {
    modalOpen = true;
  }
</script>

<span>
  <button class="px-2 py-[6px] body-small-regular bg-neutral-background rounded-md min-w-[150px]" on:click={openModal}>
    <div class="flex space-x-2 items-center">
      <i role="img" aria-label={'Chain'}>
        <EthIcon small />
      </i>
      <span>{$t('chain_selector.placeholder')}…</span>
    </div>
  </button>

  <dialog class="modal" class:modal-open={modalOpen}>
    <div class="modal-box bg-primary-base-background text-primary-base-content">
      <h3 class="title-body-bold">{$t('chain_selector.placeholder')}</h3>
      <ul class="menu">
        <li>Mainnet</li>
        <li>Taiko</li>
      </ul>
    </div>
    <div class="modal-backdrop bg-overlay-background" />
  </dialog>
</span>
