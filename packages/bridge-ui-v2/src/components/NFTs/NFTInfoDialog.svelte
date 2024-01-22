<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { destNetwork } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import type { NFT } from '$libs/token';
  import { getCrossChainAddress } from '$libs/token/getCrossChainAddress';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { uid } from '$libs/util/uid';
  import { network } from '$stores/network';

  const dialogId = `dialog-${uid()}`;

  const placeholderUrl = '/placeholder.svg';

  export let modalOpen = false;
  export let viewOnly = false;
  export let nft: NFT;

  export let srcChainId = Number($network?.id);
  export let destChainId = Number($destNetwork?.id);

  const dispatch = createEventDispatcher();

  let bridgedAddress: Address | null;

  let fetchingBridgedAddress: boolean = false;

  const selectNFT = () => {
    dispatch('selected', nft);
    closeModal();
  };

  const closeModal = () => {
    modalOpen = false;
  };

  const crossChainAddress = async () => {
    if (!srcChainId || !destChainId) return;
    fetchingBridgedAddress = true;
    bridgedAddress = await getCrossChainAddress({ token: nft, srcChainId, destChainId });
    if (nft.addresses[srcChainId] === bridgedAddress) {
      bridgedAddress = await getCrossChainAddress({ token: nft, srcChainId: destChainId, destChainId: srcChainId });
    }
    fetchingBridgedAddress = false;
  };

  $: if (modalOpen) {
    crossChainAddress();
  }

  $: currentChain = Number(srcChainId) || $network?.id;

  $: imgUrl = nft.metadata?.image || placeholderUrl;

  $: showBridgedAddress = destChainId && bridgedAddress && !fetchingBridgedAddress;
</script>

<dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
  <div class="modal-box relative px-[24px] py-[35px] md:rounded-[20px] bg-neutral-background">
    <CloseButton onClick={closeModal} />
    <div class="f-col w-full space-y-[30px]">
      <h3 class="title-body-bold">{$t('bridge.nft.step.import.nft_card.title')}</h3>
      <img alt="nft" src={imgUrl} class="rounded-[20px] self-center bg-white" />
      <div id="metadata">
        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.collection')}</div>
          <div class="text-primary-content">{nft.name}</div>
        </div>

        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.contract_address')}</div>
          <div class="text-primary-content">
            {#if currentChain}
              <a
                class="flex justify-start link"
                href={`${chainConfig[currentChain].urls.explorer}/token/${nft.addresses[currentChain]}`}
                target="_blank">
                {shortenAddress(nft.addresses[currentChain], 10, 13)}
                <Icon type="arrow-top-right" fillClass="fill-primary-link" />
              </a>
            {/if}
          </div>
        </div>

        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.bridged_address')}</div>
          <div class="text-primary-content">
            {#if showBridgedAddress && bridgedAddress}
              <a
                class="flex justify-start link"
                href={`${chainConfig[destChainId].urls.explorer}/token/${bridgedAddress}`}
                target="_blank">
                {shortenAddress(bridgedAddress, 10, 13)}
                <Icon type="arrow-top-right" fillClass="fill-primary-link" />
              </a>
            {:else}
              <Spinner class="h-2 w-2" />
            {/if}
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
          <ActionButton priority="primary" on:click={closeModal}>
            {$t('common.ok')}
          </ActionButton>
        {:else}
          <ActionButton
            priority="primary"
            class="px-[28px] py-[14px] rounded-full flex-1 w-full text-white"
            on:click={() => selectNFT()}>
            {$t('bridge.nft.step.import.nft_card.select')}
          </ActionButton>

          <button on:click={closeModal} class="flex mt-[16px] mb-0 justify-center link">
            {$t('common.cancel')}
          </button>
        {/if}
      </div>
    </div>
  </div>
</dialog>
