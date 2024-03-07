<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Address, zeroAddress } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { destNetwork } from '$components/Bridge/state';
  import { ActionButton, CloseButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import type { NFT } from '$libs/token';
  import { getTokenAddresses } from '$libs/token/getTokenAddresses';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { uid } from '$libs/util/uid';
  import { connectedSourceChain } from '$stores/network';

  const dialogId = `dialog-${uid()}`;

  const placeholderUrl = '/placeholder.svg';

  export let modalOpen: boolean;
  export let viewOnly = false;
  export let nft: NFT;

  export let srcChainId = Number($connectedSourceChain?.id);
  export let destChainId = Number($destNetwork?.id);

  const dispatch = createEventDispatcher();

  $: bridgedAddress = '' as Address;
  $: bridgedChain = 0;

  let fetchingAddress: boolean = false;

  $: canonicalAddress = '';
  $: canonicalChain = 0;

  const selectNFT = () => {
    dispatch('selected', nft);
    closeModal();
  };

  const closeModal = () => {
    modalOpen = false;
  };

  const fetchTokenAddresses = async () => {
    fetchingAddress = true;

    if (!srcChainId || !destChainId || !nft) return;

    try {
      const tokenInfo = await getTokenAddresses({ token: nft, srcChainId, destChainId });

      if (!tokenInfo) return;

      if (tokenInfo.canonical?.address && tokenInfo.canonical?.address !== zeroAddress) {
        canonicalAddress = tokenInfo.canonical?.address;
        canonicalChain = tokenInfo.canonical?.chainId;
      }

      if (tokenInfo.bridged?.address && tokenInfo.bridged?.address !== zeroAddress) {
        bridgedAddress = tokenInfo.bridged?.address;
        bridgedChain = tokenInfo.bridged?.chainId;
      }
    } catch (error) {
      console.error(error);
    }
    fetchingAddress = false;
  };

  let imageLoaded = false;

  function handleImageLoad() {
    imageLoaded = true;
  }

  $: if (modalOpen) {
    fetchTokenAddresses();
  }

  $: imageUrl = nft?.metadata?.image || placeholderUrl;

  $: showBridgedAddress = destChainId && bridgedAddress && !fetchingAddress;

  onMount(async () => {
    await fetchTokenAddresses();
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
          <div class="text-primary-content">{nft?.name}</div>
        </div>
        <!--  CANONICAL INFO -->
        <div class="f-between-center">
          <div class="f-row min-w-1/2 self-end gap-2 items-center text-secondary-content">
            {$t('common.canonical_address')}
            <img alt="source chain icon" src={chainConfig[Number(canonicalChain)]?.icon} class="w-4 h-4" />
          </div>
          <div class="f-row min-w-1/2 text-primary-content">
            {#if fetchingAddress}
              <Spinner class="h-[10px] w-[10px] " />
              {$t('common.loading')}
            {:else if canonicalChain && canonicalAddress}
              <a
                class="flex justify-start link"
                href={`${chainConfig[canonicalChain]?.blockExplorers?.default.url}/token/${canonicalAddress}`}
                target="_blank">
                {shortenAddress(canonicalAddress, 6, 8)}
                <Icon type="arrow-top-right" fillClass="fill-primary-link" />
              </a>
            {/if}
          </div>
        </div>
        <!-- BRIDGED INFO -->
        <div class="f-between-center">
          {#if showBridgedAddress && bridgedAddress}
            <div class="f-row min-w-1/2 gap-2 items-center text-secondary-content">
              {$t('common.bridged_address')}
              <img alt="destination chain icon" src={chainConfig[Number(bridgedChain)]?.icon} class="w-4 h-4" />
            </div>
            <div class="f-row min-w-1/2 text-primary-content">
              {#if bridgedChain && bridgedAddress}
                <a
                  class="flex justify-start link"
                  href={`${chainConfig[bridgedChain]?.blockExplorers?.default.url}/token/${bridgedAddress}`}
                  target="_blank">
                  {shortenAddress(bridgedAddress, 6, 8)}
                  <Icon type="arrow-top-right" fillClass="fill-primary-link" />
                </a>
              {/if}
              {#if fetchingAddress}
                <Spinner class="h-[10px] w-[10px] " />
                {$t('common.loading')}
              {/if}
            </div>
          {/if}
        </div>
        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.token_id')}</div>
          <div class="text-primary-content">{nft?.tokenId}</div>
        </div>
        <div class="f-between-center">
          <div class="text-secondary-content">{$t('common.token_standard')}</div>
          <div class="text-primary-content">{nft?.type}</div>
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
