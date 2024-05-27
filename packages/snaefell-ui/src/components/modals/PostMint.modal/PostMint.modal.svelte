<script lang="ts">
  import { getContext } from 'svelte';
  import { copy } from 'svelte-copy';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/core/Button';
  import { NftRenderer } from '$components/NftRenderer';
  import type { IMint } from '$stores/mint';
  import { Modal, ModalBody, ModalFooter } from '$ui/Modal';
  import { successToast } from '$ui/Toast';

  import {
    mintedBodyClasses,
    successContentClasses,
    successFooterWrapperClasses,
    successTitleClasses,
  } from './classes';

  function copyShareUrl(element?: EventTarget | null) {
    if (!element) return;
    copy(element as HTMLElement, `${window.location.origin}/collection/${$mintState.address}`);
    successToast({
      title: $t('content.mint.toast.clipboardCopy'),
    });
  }

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
  <ModalFooter>
    <div class={successFooterWrapperClasses}>
      <Button on:click={(event) => copyShareUrl(event.currentTarget)} wide block type="primary">
        {$t('buttons.share')}
      </Button>
    </div>
  </ModalFooter>
</Modal>
