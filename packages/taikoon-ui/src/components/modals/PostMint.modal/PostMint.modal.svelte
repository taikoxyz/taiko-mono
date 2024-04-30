<script lang="ts">
  import { getContext } from 'svelte';
  import { copy } from 'svelte-copy';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/core/Button';
  import { NftRenderer } from '$components/NftRenderer';
  import { Modal, ModalBody, ModalFooter } from '$ui/Modal';
  import { Link } from '$ui/Text';
  import { successToast } from '$ui/Toast';

  import {
    buttonWrapperClasses,
    mintedBodyClasses,
    nftRendererWrapperClasses,
    successBodyClasses,
    successContentClasses,
    successFooterWrapperClasses,
    successMintedLinkClasses,
    successTitleClasses,
  } from './classes';

  // used to horizontally scroll the minted nfts with the mouse wheel
  let scrollContainer: HTMLElement;

  function copyShareUrl(element?: EventTarget | null) {
    if (!element) return;
    copy(element as HTMLElement, `${window.location.origin}/collection/${$mintState.address}`);
    successToast({
      title: $t('content.mint.toast.clipboardCopy'),
    });
  }

  const mintState = getContext('mint');

  $: isModalOpen = $mintState.isModalOpen && !$mintState.isMinting;
</script>

<Modal bind:open={isModalOpen}>
  <ModalBody class={mintedBodyClasses}>
    <div
      bind:this={scrollContainer}
      on:wheel={(e) => {
        scrollContainer.scrollLeft += e.deltaY;
      }}
      class={successBodyClasses}>
      <div class={nftRendererWrapperClasses}>
        {#each $mintState.tokenIds as tokenId}
          <NftRenderer size="md" {tokenId} />
        {/each}
      </div>
    </div>

    <div class={successTitleClasses}>
      {$t('content.mint.modals.minted.title')}
    </div>
    <div class={successContentClasses}>
      {$t('content.mint.modals.minted.text')}

      <Link class={successMintedLinkClasses} href={`/collection/${$mintState.address}`}>
        {$t('content.mint.modals.minted.link')}</Link>
    </div>
  </ModalBody>
  <ModalFooter>
    <div class={successFooterWrapperClasses}>
      <div class={buttonWrapperClasses} use:copy={`${window.location.origin}/collection/${$mintState.address}`}>
        <Button on:click={(event) => copyShareUrl(event.currentTarget)} wide block type="primary">
          {$t('buttons.share')}
        </Button>
      </div>
      <div class={buttonWrapperClasses}>
        <Button
          on:click={() => ($mintState.isModalOpen = false)}
          href={`/collection/${$mintState.address}`}
          wide
          block
          type="negative">
          {$t('buttons.yourTaikoons')}</Button>
      </div>
    </div>
  </ModalFooter>
</Modal>
