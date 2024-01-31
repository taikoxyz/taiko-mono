<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther, formatUnits } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { Icon } from '$components/Icon';
  import { LoadingText } from '$components/LoadingText';
  import NftInfoDialog from '$components/NFTs/NFTInfoDialog.svelte';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { getChainName } from '$libs/chain';
  import { type NFT, TokenType } from '$libs/token';
  import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
  import { mapTransactionHashToNFT } from '$libs/token/mapTransactionHashToNFT';
  import { truncateString } from '$libs/util/truncateString';

  import ChainSymbolName from './ChainSymbolName.svelte';
  import InsufficientFunds from './InsufficientFunds.svelte';
  import MobileDetailsDialog from './MobileDetailsDialog.svelte';
  import { Status } from './Status';

  export let item: BridgeTransaction;
  export let loading = false;

  let token: NFT;
  let insufficientModal = false;
  let detailsOpen = false;
  let isDesktopOrLarger = false;

  $: nftInfoOpen = false;

  let attrs = isDesktopOrLarger ? {} : { role: 'button' };

  const placeholderUrl = '/placeholder.svg';

  const dispatch = createEventDispatcher();

  const handleClick = () => {
    openDetails();
    dispatch('click');
  };

  const handlePress = () => {
    openDetails();
    dispatch('press');
  };

  const closeDetails = () => {
    detailsOpen = false;
  };

  const openDetails = () => {
    if (item?.status === MessageStatus.DONE && !isDesktopOrLarger) {
      detailsOpen = true;
    }
  };

  const handleInsufficientFunds = () => {
    insufficientModal = true;
    openDetails();
  };

  async function analyzeTransactionInput(): Promise<void> {
    loading = true;
    try {
      token = await mapTransactionHashToNFT({
        hash: item.hash,
        srcChainId: Number(item.srcChainId),
        type: item.tokenType,
      });
      token = await fetchNFTImageUrl(token);
    } catch (error) {
      console.error(error);
    }
    loading = false;
  }

  $: {
    if (item.tokenType === TokenType.ERC721 || item.tokenType === TokenType.ERC1155) {
      // for NFTs we need to fetch more information about the transaction
      analyzeTransactionInput();
    }
  }

  $: imgUrl = token?.metadata?.image || placeholderUrl;

  $: itemAmountDisplay = item.tokenType === TokenType.ERC721 ? '---' : item.amount;

  $: isNFT = [TokenType.ERC1155, TokenType.ERC721].includes(item.tokenType);

  const onOpenDetails = () => {
    nftInfoOpen = true;
    nftInfoOpen = nftInfoOpen;
  };
</script>

{#if isNFT}
  <!-- We disable these warnings as we dynamically add the role -->
  <!-- svelte-ignore a11y-no-noninteractive-tabindex -->
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div class="flex text-primary-content md:h-[80px] h-[45px] w-full my-[10px] md:my-[0px]">
    {#if isDesktopOrLarger}
      <button class="w-3/12 py-2 flex flex-row space-x-[8px]" on:click={() => onOpenDetails()}>
        {#if loading}
          <div class="rounded-[10px] w-[50px] h-[50px] bg-neutral flex items-center justify-center">
            <Spinner />
          </div>
          <div class="f-col text-left space-y-1">
            <LoadingText mask="&nbsp;" class="min-w-[50px] max-w-[50px] h-4" />
            <LoadingText mask="&nbsp;" class="min-w-[90px] max-w-[90px] h-4" />
            <LoadingText mask="&nbsp;" class="min-w-[20px] max-w-[20px] h-4" />
          </div>
        {:else}
          <img alt="nft" src={imgUrl} class="rounded-[10px] min-w-[50px] max-w-[50px] bg-neutral self-center" />
          <div class="f-col text-left">
            <div class="text-sm">{token?.name ? truncateString(token?.name, 15) : ''}</div>
            <div class="text-sm text-secondary-content">
              {token?.metadata?.name ? truncateString(token?.metadata?.name, 15) : ''}
            </div>
            <div class="text-sm text-secondary-content">{token?.tokenId}</div>
          </div>
        {/if}
      </button>

      <div class="w-2/12 py-2 flex flex-row">
        <ChainSymbolName chainId={item.srcChainId} />
      </div>
      <div class="w-2/12 py-2 flex flex-row">
        <ChainSymbolName chainId={item.destChainId} />
      </div>
      <div class="w-1/12 py-2 flex flex-col self-center">
        {itemAmountDisplay}
      </div>
    {:else}
      <div class="flex text-primary-content w-full justify-content-left">
        <button class="space-x-[8px] w-1/4" on:click={() => onOpenDetails()}>
          {#if loading}
            <div class="rounded-[10px] w-[50px] h-[50px] bg-neutral flex items-center justify-center">
              <Spinner />
            </div>
          {:else}
            <img
              alt="nft"
              src={imgUrl}
              class="rounded-[10px] min-w-[46px] max-w-[46px] mr-[8px] bg-neutral self-center" />
          {/if}
        </button>
        {#if loading}
          <div class="f-col space-y-1 pl-1">
            <div class="f-row font-bold">
              <LoadingText mask="&nbsp;" class="min-w-[120px] max-w-[120px] h-4" />
            </div>
            <LoadingText mask="&nbsp;" class="min-w-[50px] max-w-[50px] h-3" />
          </div>
        {:else}
          <div class="f-col" {...attrs} tabindex="0" on:click={handleClick} on:keydown={handlePress}>
            <div class="f-row font-bold">
              {getChainName(Number(item.srcChainId))}
              <i role="img" aria-label="arrow to" class="mx-auto px-2">
                <Icon type="arrow-right" />
              </i>
              {getChainName(Number(item.destChainId))}
            </div>
            <span class="text-secondary-content">{token?.name ? truncateString(token?.name, 15) : ''}</span>
          </div>
        {/if}
      </div>
    {/if}
    <div
      class="flex md:w-2/12 py-2 flex flex-col justify-center text-center"
      {...attrs}
      tabindex="0"
      on:click={handleClick}
      on:keydown={handlePress}>
      <Status
        on:click={isDesktopOrLarger ? undefined : openDetails}
        bridgeTx={item}
        on:insufficientFunds={handleInsufficientFunds} />
    </div>
    <div class="hidden md:flex grow py-2 flex flex-col justify-center">
      <a
        class="flex justify-center py-3 link"
        href={`${chainConfig[Number(item.srcChainId)].urls.explorer}/tx/${item.hash}`}
        target="_blank">
        {$t('transactions.link.explorer')}
        <Icon type="arrow-top-right" fillClass="fill-primary-link" />
      </a>
    </div>
  </div>
{:else}
  <!-- We disable these warnings as we dynamically add the role -->
  <!-- svelte-ignore a11y-no-noninteractive-tabindex -->
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    {...attrs}
    tabindex="0"
    on:click={handleClick}
    on:keydown={handlePress}
    class="flex text-primary-content md:h-[80px] h-[45px] w-full my-[10px] md:my-[0px]">
    {#if isDesktopOrLarger}
      <div class="w-1/5 py-2 flex flex-row">
        <ChainSymbolName chainId={item.srcChainId} />
      </div>
      <div class="w-1/5 py-2 flex flex-row">
        <ChainSymbolName chainId={item.destChainId} />
      </div>
      <div class="w-1/5 py-2 flex flex-col justify-center">
        {#if item.tokenType === TokenType.ERC20}
          {formatUnits(item.amount ? item.amount : BigInt(0), item.decimals)}
        {:else if item.tokenType === TokenType.ETH}
          {formatEther(item.amount ? item.amount : BigInt(0))}
        {/if}
        {item.symbol}
      </div>
    {:else}
      <div class="flex text-primary-content w-full">
        <div class="flex-col">
          <div class="flex font-bold">
            {getChainName(Number(item.srcChainId))}
            <i role="img" aria-label="arrow to" class="mx-auto px-2">
              <Icon type="arrow-right" />
            </i>
            {getChainName(Number(item.destChainId))}
          </div>
          <div class=" flex flex-col justify-center text-sm text-secondary-content">
            {#if item.tokenType === TokenType.ERC20}
              {formatUnits(item.amount ? item.amount : BigInt(0), item.decimals)}
            {:else if item.tokenType === TokenType.ETH}
              {formatEther(item.amount ? item.amount : BigInt(0))}
            {/if}
            {item.symbol}
          </div>
        </div>
      </div>
    {/if}

    <div class="sm:w-1/4 md:w-1/5 py-2 flex flex-col justify-center">
      <Status
        on:click={isDesktopOrLarger ? undefined : openDetails}
        bridgeTx={item}
        on:insufficientFunds={handleInsufficientFunds} />
    </div>
    <div class="hidden md:flex w-1/5 py-2 flex flex-col justify-center">
      <a
        class="flex justify-start py-3 link"
        href={`${chainConfig[Number(item.srcChainId)].urls.explorer}/tx/${item.hash}`}
        target="_blank">
        {$t('transactions.link.explorer')}
        <Icon type="arrow-top-right" fillClass="fill-primary-link" />
      </a>
    </div>
  </div>
{/if}

<DesktopOrLarger bind:is={isDesktopOrLarger} />

<MobileDetailsDialog {closeDetails} {detailsOpen} selectedItem={item} on:insufficientFunds={handleInsufficientFunds} />

{#if token}
  <NftInfoDialog
    bind:modalOpen={nftInfoOpen}
    nft={token}
    srcChainId={Number(item.srcChainId)}
    destChainId={Number(item.destChainId)}
    viewOnly />
{/if}

<InsufficientFunds bind:modalOpen={insufficientModal} />
