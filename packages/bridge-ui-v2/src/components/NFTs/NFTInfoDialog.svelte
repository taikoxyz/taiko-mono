<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Address, zeroAddress } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { destNetwork } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import type { NFT, Token } from '$libs/token';
  import { getCanonicalInfoForToken } from '$libs/token/getCanonicalInfoForToken';
  import { getCrossChainInfoForToken } from '$libs/token/getCrossChainInfoForToken';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { uid } from '$libs/util/uid';
  import { network } from '$stores/network';

  const dialogId = `dialog-${uid()}`;

  const placeholderUrl = '/placeholder.svg';

  export let modalOpen: boolean;
  export let viewOnly = false;
  export let nft: NFT;

  export let srcChainId = Number($network?.id);
  export let destChainId = Number($destNetwork?.id);

  const dispatch = createEventDispatcher();

  let bridgedAddress: Address | null;
  let bridgedChain: number | null;

  let fetchingBridgedAddress: boolean = false;

  let canonicalAddress: Address | null;
  let canonicalChain: number | null;

  const selectNFT = () => {
    dispatch('selected', nft);
    closeModal();
  };

  const closeModal = () => {
    modalOpen = false;
  };

  const getBridgedAddress = async () => {
    const srcChain = canonicalChain;
    const destChain = destChainId === canonicalChain ? srcChainId : destChainId;
    if (!srcChain || !destChain || !canonicalAddress) return;

    fetchingBridgedAddress = true;
    try {
      const response = await getCrossChainInfoForToken({ token: nft, srcChainId: srcChain, destChainId: destChain });
      if (!response) return;
      const { address, chainId } = response;
      if (!address || !chainId) return;
      bridgedAddress = address;
      bridgedChain = chainId;
      if (address === zeroAddress) bridgedAddress = null;
    } catch (error) {
      console.error(error);
    }

    fetchingBridgedAddress = false;
  };

  let imageLoaded = false;

  function handleImageLoad() {
    imageLoaded = true;
  }

  const getCanonicalAddress = async () => {
    const token = nft as Token;
    if (!srcChainId || !destChainId) return;

    const response = await getCanonicalInfoForToken({ token, srcChainId, destChainId });

    if (!response) return;
    const { address, chainId } = response;
    if (!address || !chainId) return;
    canonicalAddress = address;
    canonicalChain = chainId;
  };

  $: imageUrl = nft.metadata?.image || placeholderUrl;

  $: showBridgedAddress = destChainId && bridgedAddress && !fetchingBridgedAddress;

  onMount(async () => {
    await getCanonicalAddress();
    await getBridgedAddress();
  });
</script>

<dialog id={dialogId} class="modal modal-bottom md:modal-middle" class:modal-open={modalOpen}>
  <div class="modal-box relative px-[24px] py-[35px] md:rounded-[20px] bg-neutral-background">
    <CloseButton onClick={closeModal} />
    <div class="f-col w-full space-y-[30px]">
      <h3 class="title-body-bold">{$t('bridge.nft.step.import.nft_card.title')}</h3>
      {#if !imageLoaded}
        <img alt="placeholder" src={placeholderUrl} class="rounded-[20px] self-center bg-white" />
      {/if}
      <img
        alt="nft"
        src={imageUrl || ''}
        class="rounded-[20px] self-center bg-white {!imageLoaded || imageUrl === '' ? 'hidden' : ''}"
        on:load={handleImageLoad} />
      <div id="metadata">
        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.collection')}</div>
          <div class="text-primary-content">{nft.name}</div>
        </div>
        <!--  CANONICAL INFO -->
        <div class="f-between-center">
          <div class="f-row gap-2 items-center text-secondary-content">
            {$t('common.canonical_address')}
            <img alt="source chain icon" src={chainConfig[Number(canonicalChain)]?.icon} class="w-4 h-4" />
          </div>
          <div class="text-primary-content">
            {#if canonicalChain && canonicalAddress}
              <a
                class="flex justify-start link"
                href={`${chainConfig[canonicalChain].urls.explorer}/token/${canonicalAddress}`}
                target="_blank">
                {shortenAddress(canonicalAddress, 10, 13)}
                <Icon type="arrow-top-right" fillClass="fill-primary-link" />
              </a>
            {/if}
          </div>
        </div>
        <!-- BRIDGED INFO -->
        <div class="f-between-center">
          {#if showBridgedAddress && bridgedAddress}
            <div class="f-row gap-2 items-center text-secondary-content">
              {$t('common.bridged_address')}
              <img alt="destination chain icon" src={chainConfig[Number(bridgedChain)]?.icon} class="w-4 h-4" />
            </div>
            <div class="text-primary-content">
              {#if bridgedChain && bridgedAddress}
                <a
                  class="flex justify-start link"
                  href={`${chainConfig[bridgedChain].urls.explorer}/token/${bridgedAddress}`}
                  target="_blank">
                  {shortenAddress(bridgedAddress, 10, 13)}
                  <Icon type="arrow-top-right" fillClass="fill-primary-link" />
                </a>
              {/if}
              {#if fetchingBridgedAddress}
                <Spinner class="h-[10px] w-[10px] " />
                {$t('common.loading')}
              {/if}
            </div>
          {/if}
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
