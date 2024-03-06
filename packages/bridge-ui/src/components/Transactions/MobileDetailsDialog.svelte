<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Address, formatEther, zeroAddress } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { destNetwork } from '$components/Bridge/state';
  import { CloseButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { Spinner } from '$components/Spinner';
  import type { BridgeTransaction } from '$libs/bridge';
  import { type NFT, TokenType } from '$libs/token';
  import { getTokenAddresses } from '$libs/token/getTokenAddresses';
  import { noop } from '$libs/util/noop';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { uid } from '$libs/util/uid';
  import { connectedSourceChain } from '$stores/network';

  import ChainSymbolName from './ChainSymbolName.svelte';
  import { StatusInfoDialog } from './Status';
  import Status from './Status/Status.svelte';

  export let closeDetails = noop;
  export let detailsOpen = false;
  export let token: NFT;
  export let selectedItem: BridgeTransaction;

  const dispatch = createEventDispatcher();
  const placeholderUrl = '/placeholder.svg';

  let openStatusDialog = false;

  let tooltipOpen = false;
  const openToolTip = (event: Event) => {
    event.stopPropagation();
    tooltipOpen = !tooltipOpen;
  };
  let dialogId = `dialog-${uid()}`;

  const handleStatusDialog = () => {
    openStatusDialog = !openStatusDialog;
  };

  const handleInsufficientFunds = (e: CustomEvent) => {
    dispatch('insufficientFunds', e.detail);
  };

  export let srcChainId = Number($connectedSourceChain?.id);
  export let destChainId = Number($destNetwork?.id);

  let bridgedAddress: Address | null;
  let bridgedChain: number | null;

  let fetchingAddress: boolean = false;

  let canonicalAddress: Address | null;
  let canonicalChain: number | null;

  $: if (token && !fetchingAddress && !canonicalAddress && !bridgedAddress) {
    fetchTokenAddresses();
  }

  const fetchTokenAddresses = async () => {
    if (!token) return;
    fetchingAddress = true;

    if (!srcChainId || !destChainId) return;

    try {
      const tokenInfo = await getTokenAddresses({ token, srcChainId, destChainId });

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

  $: imageUrl = token?.metadata?.image || placeholderUrl;

  $: isERC721 = selectedItem?.tokenType === TokenType.ERC721;
  $: isERC1155 = selectedItem?.tokenType === TokenType.ERC1155;
  $: isNFT = isERC721 || isERC1155;

  $: showBridgedAddress = destChainId && bridgedAddress && !fetchingAddress;
</script>

<dialog id={dialogId} class="modal modal-bottom" class:modal-open={detailsOpen}>
  <div class="modal-box relative w-full bg-neutral-background !p-0 !pb-[20px]">
    <div class="w-full pt-[35px] px-[24px]">
      <CloseButton onClick={closeDetails} />
      <h3 class="font-bold">{$t('transactions.details_dialog.title')}</h3>
    </div>
    <div class="h-sep my-[20px]" />
    <div class="w-full px-[24px] text-left">
      {#if selectedItem}
        {#if isNFT}
          <div class="space-y-[20px] mb-[20px]">
            <div class="f-between-center">
              <div class="text-primary-content font-bold">{token?.name} #{token?.tokenId}</div>
              <span class="badge badge-primary badge-outline badge-xs px-[10px] h-[24px] ml-[10px]">
                <span class="text-xs">{token?.type}</span>
              </span>
            </div>
            <img alt="nft" src={imageUrl} />
          </div>
        {/if}
        <ul class="space-y-[15px] body-small-regular w-full">
          <li class="f-between-center">
            <h4 class="text-secondary-content">
              <div class="f-items-center space-x-1">
                <button on:click={openToolTip}>
                  <span>{$t('transactions.header.status')}</span>
                </button>
                <button on:click={handleStatusDialog} class="flex justify-start content-center">
                  <Icon type="question-circle" />
                </button>
              </div>
            </h4>
            <div class="f-items-center space-x-1">
              <Status bridgeTx={selectedItem} on:insufficientFunds={handleInsufficientFunds} />
            </div>
          </li>

          {#if isNFT}
            <div class="h-sep" />
            <!--  CANONICAL INFO -->
            {#if canonicalChain && canonicalAddress}
              <div class="f-between-center">
                <div class="f-row min-w-1/2 self-end gap-2 items-center text-secondary-content">
                  {$t('common.canonical_address')}
                  <img alt="source chain icon" src={chainConfig[Number(canonicalChain)]?.icon} class="w-4 h-4" />
                </div>
                <div class="f-row min-w-1/2 text-primary-content">
                  <a
                    class="flex justify-start link"
                    href={`${chainConfig[canonicalChain]?.blockExplorers?.default.url}/token/${canonicalAddress}`}
                    target="_blank">
                    {shortenAddress(canonicalAddress, 6, 8)}
                  </a>
                </div>
              </div>
            {/if}
            <!-- BRIDGED INFO -->
            {#if showBridgedAddress && bridgedAddress}
              <div class="f-between-center">
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
              </div>
            {/if}
          {/if}

          <li class="f-between-center">
            <h4 class="text-secondary-content">{$t('common.from')}</h4>
            <ChainSymbolName chainId={selectedItem.srcChainId} />
          </li>
          <li class="f-between-center">
            <h4 class="text-secondary-content">{$t('common.to')}</h4>
            <ChainSymbolName chainId={selectedItem.destChainId} />
          </li>
          {#if !isERC721}
            <li class="f-between-center">
              <h4 class="text-secondary-content">{$t('inputs.amount.label')}</h4>
              <span>{formatEther(selectedItem.amount ? selectedItem.amount : BigInt(0))} {selectedItem.symbol}</span>
            </li>
          {/if}
          <li class="f-between-center">
            <h4 class="text-secondary-content">{$t('transactions.header.explorer')}</h4>
            <a
              class="flex justify-start content-center link"
              href={`${chainConfig[Number(selectedItem.srcChainId)]?.blockExplorers?.default.url}/tx/${selectedItem.hash}`}
              target="_blank">
              {$t('transactions.link.explorer')}
              <Icon type="arrow-top-right" />
            </a>
          </li>
        </ul>
      {/if}
    </div>

    <button class="overlay-backdrop" on:click={closeDetails} />
  </div>
</dialog>

<StatusInfoDialog bind:modalOpen={openStatusDialog} noIcon />
