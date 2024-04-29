<script lang="ts">
  import { getContext } from 'svelte';
  import { copy } from 'svelte-copy';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/core/Button';
  import { Spinner } from '$components/core/Spinner';
  import { NftRenderer } from '$components/NftRenderer';
  import { Icons } from '$ui/Icons';
  import { Modal, ModalBody, ModalFooter, ModalTitle } from '$ui/Modal';
  import { Link } from '$ui/Text';
  import { successToast } from '$ui/Toast';

  import {
    bodyWrapperClasses,
    buttonWrapperClasses,
    footerWrapperClasses,
    linkClasses,
    mintedBodyClasses,
    nftRendererWrapperClasses,
    spinnerMdWrapper,
    spinnerSmWrapper,
    successBodyClasses,
    successContentClasses,
    successFooterWrapperClasses,
    successMintedLinkClasses,
    successTitleClasses,
    textClasses,
  } from './classes';

  const { UpRightArrow } = Icons;

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
</script>

<Modal bind:open={$mintState.isModalOpen}>
  {#if $mintState.isMinting}
    <ModalTitle>
      {$mintState.isMinting
        ? $t('content.mint.modals.minting.title', {
            values: {
              count: $mintState.totalMintCount,
              plural: $mintState.totalMintCount === 1 ? '' : 's',
            },
          })
        : ''}
    </ModalTitle>
    <ModalBody>
      <div class={bodyWrapperClasses}>
        {#if $mintState.txHash}
          {$t('content.mint.modals.minting.pending')}
        {:else}
          {$t('content.mint.modals.minting.confirm')}
        {/if}
      </div>
    </ModalBody>
    <ModalFooter>
      <div class={footerWrapperClasses}>
        {#if $mintState.txHash}
          <div class={spinnerSmWrapper}>
            <Spinner size="sm" />
          </div>
          <div>
            <div class={textClasses}>Waiting for confirmation</div>
            <a href={`https://etherscan.io/tx/${$mintState.txHash}`} target="_blank" class={linkClasses}
              >{$t('buttons.etherscan')}
              <UpRightArrow size="10" />
            </a>
          </div>
        {:else}
          <div class={spinnerMdWrapper}>
            <Spinner size="md" />
          </div>
        {/if}
      </div>
    </ModalFooter>
  {:else}
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
  {/if}
</Modal>
