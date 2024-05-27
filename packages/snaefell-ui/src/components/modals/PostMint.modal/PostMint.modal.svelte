<script lang="ts">
  import { getContext } from 'svelte';
  import { t } from 'svelte-i18n';

  import { NftRenderer } from '$components/NftRenderer';
  import type { IMint } from '$stores/mint';
  import { Modal, ModalBody } from '$ui/Modal';

  import { mintedBodyClasses, successContentClasses, successTitleClasses } from './classes';

  const mintState = getContext<IMint>('mint');

  $: isModalOpen = $mintState.isModalOpen && !$mintState.isMinting;
</script>

<Modal open={isModalOpen}>
  <ModalBody class={mintedBodyClasses}>
    <NftRenderer size="xl" />

    <div class={successTitleClasses}>
      {$t('content.mint.modals.minted.title')}
    </div>
    <div class={successContentClasses}>
      {$t('content.mint.modals.minted.text')}
    </div>
  </ModalBody>
</Modal>
