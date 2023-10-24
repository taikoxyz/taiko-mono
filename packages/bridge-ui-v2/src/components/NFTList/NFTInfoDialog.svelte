<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { CloseButton } from '$components/CloseButton';
  import type { NFT } from '$libs/token';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { uid } from '$libs/util/uid';
  import { network } from '$stores/network';

  const dialogId = `dialog-${uid()}`;

  const placeholderUrl = 'https://placehold.co/600x600.png';

  export let modalOpen = false;
  export let viewOnly = false;

  export let nft: NFT;

  const dispatch = createEventDispatcher();

  const selectNFT = () => {
    dispatch('selected');
    closeModal();
  };

  const closeModal = () => {
    modalOpen = false;
  };
</script>

<dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
  <div class="modal-box relative px-[24px] py-[35px] md:rounded-[20px] bg-neutral-background">
    <CloseButton onClick={closeModal} />

    <div class="f-col w-full space-y-[30px]">
      <h3 class="title-body-bold">{$t('bridge.nft.step.import.nft_card.title')}</h3>

      <img alt="placeholder nft" src={nft.metadata?.image || placeholderUrl} class="rounded-[20px] self-center" />
      <div id="metadata">
        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.collection')}</div>
          <div class="text-primary-content">{nft.name}</div>
        </div>
        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.contract_address')}</div>
          <div class="text-primary-content">
            {$network?.id ? shortenAddress(nft.addresses[$network?.id], 10, 13) : ''}
          </div>
        </div>

        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.token_id')}</div>
          <div class="text-primary-content">{nft.tokenId}</div>
        </div>
        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.token_standard')}</div>
          <div class="text-primary-content">{nft.type}</div>
        </div>
      </div>
      <div class="f-col">
        {#if viewOnly}
          <Button
            type="primary"
            hasBorder={true}
            class="px-[28px] py-[14px] rounded-full flex-1 w-full"
            on:click={closeModal}>
            {$t('common.ok')}
          </Button>
        {:else}
          <Button
            type="primary"
            hasBorder={true}
            class="px-[28px] py-[14px] rounded-full flex-1 w-full"
            on:click={() => selectNFT()}>
            {$t('bridge.nft.step.import.nft_card.select')}
          </Button>

          <button on:click={closeModal} class="flex mt-[16px] mb-0 justify-center link">
            {$t('common.cancel')}
          </button>
        {/if}
      </div>
    </div>
  </div>
</dialog>
