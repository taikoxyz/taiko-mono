<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Icon } from '$components/Icon';
  import { bridgePausedModal } from '$stores/modal';
</script>

<dialog class="modal modal-bottom md:modal-middle" class:modal-open={$bridgePausedModal}>
  <div
    class="modal-box relative px-6 py-[35px] md:py-[35px] bg-neutral-background text-primary-content box-shadow-small">
    <h3 class="title-body-bold mb-[30px]">{$t('paused_modal.title')}</h3>
    <Icon type="info-circle" size={200} fillClass="fill-warning-sentiment" class="mb-4" />
    <p class="body-regular text-center mb-[20px]">{$t('paused_modal.description')}</p>
  </div>
</dialog>
