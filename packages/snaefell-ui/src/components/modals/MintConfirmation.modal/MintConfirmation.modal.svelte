<script lang="ts">
  import { getContext } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Spinner } from '$components/core/Spinner';
  import { NftRenderer } from '$components/NftRenderer';
  import type { IMint } from '$stores/mint';
  import { Icons } from '$ui/Icons';
  import { Modal, ModalBody, ModalFooter, ModalTitle } from '$ui/Modal';

  import {
    bodyWrapperClasses,
    footerWrapperClasses,
    linkClasses,
    modalContentWrapperClasses,
    modalTitleClasses,
    spinnerMdWrapper,
    spinnerSmWrapper,
    textClasses,
  } from './classes';

  const { UpRightArrow } = Icons;

  const mintState = getContext<IMint>('mint');

  $: isModalOpen = $mintState.isModalOpen && $mintState.isMinting;
</script>

<Modal open={isModalOpen}>
  <div class={modalContentWrapperClasses}>
    <ModalTitle class={modalTitleClasses}>
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
        <NftRenderer size="xl" />

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
  </div>
</Modal>
