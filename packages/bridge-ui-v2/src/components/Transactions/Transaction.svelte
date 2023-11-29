<script lang="ts">
  import { fetchTransaction, type Hash } from '@wagmi/core';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { decodeFunctionData, formatEther, formatUnits } from 'viem';

  import { erc721VaultABI, erc1155VaultABI } from '$abi';
  import { chainConfig } from '$chainConfig';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { Icon } from '$components/Icon';
  import { LoadingText } from '$components/LoadingText';
  import NftInfoDialog from '$components/NFTs/NFTInfoDialog.svelte';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { type NFT, TokenType } from '$libs/token';
  import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
  import { getTokenWithInfoFromAddress } from '$libs/token/getTokenWithInfoFromAddress';
  import { truncateString } from '$libs/util/truncateString';

  import ChainSymbolName from './ChainSymbolName.svelte';
  import InsufficientFunds from './InsufficientFunds.svelte';
  import MobileDetailsDialog from './MobileDetailsDialog.svelte';
  import Status from './Status.svelte';

  export let item: BridgeTransaction;

  let token: NFT;

  export let loading = false;

  const dispatch = createEventDispatcher();
  let insufficientModal = false;
  let detailsOpen = false;
  let isDesktopOrLarger = false;

  let nftInfoOpen = false;

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
    if (item.tokenType === TokenType.ETH || item.tokenType === TokenType.ERC20) return; // no special treatment for ETH or ERC20
    const hash = item.hash as Hash;
    loading = true;
    // Retrieve transaction data
    const transactionData = await fetchTransaction({ hash, chainId: Number(item.srcChainId) });

    const abi = (() => {
      switch (item.tokenType) {
        case TokenType.ERC721:
          return erc721VaultABI;
        case TokenType.ERC1155:
          return erc1155VaultABI;
        default:
          throw new Error('Invalid token type');
      }
    })();

    const { functionName, args: decodedInputData } = await decodeFunctionData({
      abi,
      data: transactionData.input,
    });
    if (!decodedInputData) throw new Error('Invalid input data');

    if (functionName !== 'sendToken') throw new Error('Invalid function name');

    const { token: tokenAddress, tokenIds } = decodedInputData[0];

    token = (await getTokenWithInfoFromAddress({
      contractAddress: tokenAddress,
      srcChainId: Number(item.srcChainId),
      owner: item.from,
      tokenId: Number(tokenIds[0]),
      type: item.tokenType,
    })) as NFT;
    token = await fetchNFTImageUrl(token, Number(item.srcChainId), Number(item.destChainId));

    loading = false;
  }

  $: analyzeTransactionInput();

  let attrs = isDesktopOrLarger ? {} : { role: 'button' };

  const placeholderUrl = '/placeholder.svg';

  $: imgUrl = token?.metadata?.image || placeholderUrl;

  $: itemAmountDisplay = item.tokenType === TokenType.ERC721 ? '---' : item.amount;

  $: isNFT = [TokenType.ERC1155, TokenType.ERC721].includes(item.tokenType);
</script>

{#if isNFT}
  <!-- We disable these warnings as we dynamically add the role -->
  <!-- svelte-ignore a11y-no-noninteractive-tabindex -->
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    {...attrs}
    tabindex="0"
    on:click={handleClick}
    on:keydown={handlePress}
    class="flex text-primary-content items-center md:h-[80px] h-[45px] w-full relative">
    {#if isDesktopOrLarger}
      <button class="w-2/6 py-2 flex flex-row space-x-[8px]" on:click={() => (nftInfoOpen = true)}>
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

      <div class="w-1/6 py-2 flex flex-row">
        <ChainSymbolName chainId={item.srcChainId} />
      </div>
      <div class="w-1/6 py-2 flex flex-row">
        <ChainSymbolName chainId={item.destChainId} />
      </div>
      <div class="w-1/6 py-2 flex flex-col justify-center">
        {itemAmountDisplay}
      </div>
    {:else}
      TODO: mobile view
    {/if}
    <div class="sm:w-1/4 md:w-1/6 py-2 flex flex-col justify-center">
      <Status
        on:click={isDesktopOrLarger ? undefined : openDetails}
        bridgeTx={item}
        on:insufficientFunds={handleInsufficientFunds} />
      <!-- <div class="btn btn-primary" on:click={isDesktopOrLarger ? undefined : openDetails}></div> -->
    </div>
    <div class="hidden md:flex w-1/6 py-2 flex flex-col justify-center">
      <a
        class="flex justify-start py-3 link"
        href={`${chainConfig[Number(item.srcChainId)].urls.explorer}/tx/${item.hash}`}
        target="_blank">
        {$t('transactions.link.explorer')}
        <Icon type="arrow-top-right" fillClass="fill-primary-link" />
      </a>
    </div>
  </div>
{:else if !isNFT}
  <!-- We disable these warnings as we dynamically add the role -->
  <!-- svelte-ignore a11y-no-noninteractive-tabindex -->
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    {...attrs}
    tabindex="0"
    on:click={handleClick}
    on:keydown={handlePress}
    class="flex text-primary-content md:h-[80px] h-[45px] w-full">
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
      <div class="flex text-primary-content h-[80px] w-full">
        <div class="flex-col">
          <div class="flex">
            <ChainSymbolName chainId={item.srcChainId} />
            <i role="img" aria-label="arrow to" class="mx-auto px-2">
              <Icon type="arrow-right" />
            </i>
            <ChainSymbolName chainId={item.destChainId} />
          </div>
          <div class="py-2 flex flex-col justify-center">
            {formatEther(item.amount ? item.amount : BigInt(0))}
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
      <!-- <div class="btn btn-primary" on:click={isDesktopOrLarger ? undefined : openDetails}></div> -->
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
  <NftInfoDialog bind:modalOpen={nftInfoOpen} nft={token} srcChainId={Number(item.srcChainId)} viewOnly />
{/if}

<InsufficientFunds bind:modalOpen={insufficientModal} />
