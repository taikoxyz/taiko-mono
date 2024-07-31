<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther, formatUnits, hexToBigInt } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { ClaimDialog, ReleaseDialog, RetryDialog } from '$components/Dialogs';
  import { Icon } from '$components/Icon';
  import { LoadingText } from '$components/LoadingText';
  import NftInfoDialog from '$components/NFTs/NFTInfoDialog.svelte';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { getMessageStatusForMsgHash } from '$libs/bridge/getMessageStatusForMsgHash';
  import { getChainName } from '$libs/chain';
  import { type NFT, TokenType } from '$libs/token';
  import { fetchNFTImageUrl } from '$libs/token/fetchNFTImageUrl';
  import { mapTransactionHashToNFT } from '$libs/token/mapTransactionHashToNFT';
  import { formatTimestamp } from '$libs/util/formatTimestamp';
  import { geBlockTimestamp } from '$libs/util/getBlockTimestamp';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { truncateString } from '$libs/util/truncateString';

  import ChainSymbol from './ChainSymbol.svelte';
  import DesktopDetailsDialog from './Dialogs/DesktopDetailsDialog.svelte';
  import InsufficientFunds from './InsufficientFunds.svelte';
  import MobileDetailsDialog from './MobileDetailsDialog.svelte';
  import { Status } from './Status';

  export let item: BridgeTransaction;
  export let loading = false;
  export let handleTransactionRemoved: (event: CustomEvent) => void;

  let token: NFT;
  let insufficientModal = false;
  let nftInfoOpen = false;
  let isDesktopOrLarger = false;
  let mobileDetailsOpen = false;
  let desktopDetailsOpen = false;

  export let bridgeTxStatus: Maybe<MessageStatus>;

  let attrs = isDesktopOrLarger ? {} : { role: 'button' };

  const placeholderUrl = '/placeholder.svg';

  const openNFTInfo = () => {
    nftInfoOpen = true;
  };

  const openDetails = () => {
    if (!isDesktopOrLarger && !interactiveDialogsOpen) {
      mobileDetailsOpen = true;
    } else if (isDesktopOrLarger && !interactiveDialogsOpen) {
      desktopDetailsOpen = true;
    }
  };

  const closeDetails = () => {
    mobileDetailsOpen = false;
    desktopDetailsOpen = false;
  };

  const handleInsufficientFunds = () => {
    insufficientModal = true;
  };

  const handleOpenModal = (event: CustomEvent) => {
    if (event.detail === 'retry') {
      retryModalOpen = true;
    } else if (event.detail === 'release') {
      releaseModalOpen = true;
    } else if (event.detail === 'claim') {
      claimModalOpen = true;
    }
  };

  async function analyzeTransactionInput(): Promise<void> {
    loading = true;
    try {
      token = await mapTransactionHashToNFT({
        hash: item.srcTxHash,
        srcChainId: Number(item.srcChainId),
        type: item.tokenType,
      });
      token = await fetchNFTImageUrl(token);
      await getDate();
    } catch (error) {
      console.error(error);
    }
    loading = false;
  }

  async function claimingDone() {
    // Keeping model and UI in sync
    item.msgStatus = await getMessageStatusForMsgHash({
      msgHash: item.msgHash,
      srcChainId: Number(item.srcChainId),
      destChainId: Number(item.destChainId),
    });
    bridgeTxStatus = item.msgStatus;
  }

  const handleStatusChange = (event: CustomEvent<MessageStatus>) => {
    bridgeTxStatus = event.detail;
  };

  const getDate = async () => {
    const blockTimestamp = await geBlockTimestamp(item.srcChainId, hexToBigInt(item.blockNumber));
    timestamp = formatTimestamp(Number(blockTimestamp));
  };

  $: {
    if (item.tokenType === TokenType.ERC721 || item.tokenType === TokenType.ERC1155) {
      // for NFTs we need to fetch more information about the transaction
      analyzeTransactionInput();
    } else {
      getDate();
    }
  }

  $: imgUrl = token?.metadata?.image || placeholderUrl;

  $: itemAmountDisplay = item.tokenType === TokenType.ERC721 ? '---' : item.amount;

  $: isNFT = [TokenType.ERC1155, TokenType.ERC721].includes(item.tokenType);

  $: claimModalOpen = false;
  $: retryModalOpen = false;
  $: releaseModalOpen = false;

  $: interactiveDialogsOpen = claimModalOpen || retryModalOpen || releaseModalOpen;

  let timestamp: string;
</script>

{#if isNFT}
  <!-- We disable these warnings as we dynamically add the role -->
  <!-- svelte-ignore a11y-no-noninteractive-tabindex -->
  <div class="flex items-center text-primary-content md:h-[80px] h-[45px] w-full my-[10px] md:my-[0px]">
    {#if isDesktopOrLarger}
      <div class="flex md:w-3/12 gap-[8px]">
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
          <button on:click={() => openNFTInfo()}>
            <img
              alt="nft"
              src={imgUrl}
              class="rounded-[10px] min-w-[50px] max-w-[50px] bg-neutral self-center" /></button>
          <div class="f-col text-left">
            <div class="text-sm">{token?.name ? truncateString(token?.name, 15) : 'No Token Name'}</div>
            <div class="text-sm text-secondary-content">
              {token?.metadata?.name ? truncateString(token?.metadata?.name, 15) : ''}
            </div>
            <div class="text-sm text-secondary-content">{token?.tokenId}</div>
          </div>
        {/if}
      </div>
      <div class="w-2/12 py-2 flex flex-row">
        <ChainSymbol chainId={item.srcChainId} />
      </div>
      <div class="w-2/12 py-2 flex flex-row">
        <ChainSymbol chainId={item.destChainId} />
      </div>
      <div class="w-1/12 py-2 flex flex-col self-center">
        {itemAmountDisplay}
      </div>
    {:else}
      <!-- svelte-ignore a11y-no-static-element-interactions -->
      <div on:click={openDetails} {...attrs} class="flex text-primary-content w-full justify-content-left">
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

        {#if loading}
          <div class="f-col space-y-1 pl-1">
            <div class="f-row font-bold">
              <LoadingText mask="&nbsp;" class="min-w-[120px] max-w-[120px] h-4" />
            </div>
            <LoadingText mask="&nbsp;" class="min-w-[50px] max-w-[50px] h-3" />
          </div>
        {:else}
          <div class="f-col" tabindex="0">
            <div class="f-row font-bold">
              {truncateString(getChainName(Number(item.srcChainId)), 8)}
              <i role="img" aria-label="arrow to" class="mx-auto px-2">
                <Icon type="arrow-right" />
              </i>
              {truncateString(getChainName(Number(item.destChainId)), 8)}
            </div>
            <span class="text-secondary-content">{token?.name ? truncateString(token?.name, 15) : ''}</span>
          </div>
        {/if}
      </div>
    {/if}
    <div class="flex md:w-2/12 py-2 flex flex-col justify-center text-center" {...attrs} tabindex="0">
      <Status
        bridgeTx={item}
        bind:bridgeTxStatus
        on:transactionRemoved={handleTransactionRemoved}
        on:openModal={handleOpenModal}
        on:insufficientFunds={handleInsufficientFunds} />
    </div>
    <div class="hidden md:flex grow py-2 flex flex-col justify-center">
      <a
        class="flex justify-center py-3 link"
        href={`${chainConfig[Number(item.srcChainId)]?.blockExplorers?.default.url}/tx/${item.srcTxHash}`}
        target="_blank">
        {$t('transactions.link.explorer')}
        <Icon type="arrow-top-right" fillClass="fill-primary-link" />
      </a>
    </div>
  </div>
{:else}
  <!-- svelte-ignore a11y-no-static-element-interactions -->
  <div
    on:click={openDetails}
    {...attrs}
    class="flex text-primary-content md:h-[80px] h-[45px] w-full my-[10px] md:my-[0px] hover:bg-[#C8047D]/10">
    {#if isDesktopOrLarger}
      <div class="w-1/6 py-2 pl-[24px] flex flex-row items-center">
        <ChainSymbol class="min-w-[24px]" chainId={item.srcChainId} />
        {shortenAddress(item.message?.from)}
      </div>
      <div class="w-1/6 py-2 flex flex-row items-center">
        <ChainSymbol class="min-w-[24px]" chainId={item.destChainId} />
        {shortenAddress(item.message?.to)}
      </div>
      <div class="w-1/6 py-2 flex flex-col justify-center">
        {#if item.tokenType === TokenType.ERC20}
          {formatUnits(item.amount ? item.amount : BigInt(0), item.decimals ?? 0)}
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
              {formatUnits(item.amount ? item.amount : BigInt(0), item.decimals ?? 0)}
            {:else if item.tokenType === TokenType.ETH}
              {formatEther(item.amount ? item.amount : BigInt(0))}
            {/if}
            {item.symbol}
          </div>
        </div>
      </div>
    {/if}

    <div class="md:w-1/6 py-2 flex flex-col justify-center">
      <Status
        bridgeTx={item}
        on:transactionRemoved={handleTransactionRemoved}
        bind:bridgeTxStatus
        on:openModal={handleOpenModal}
        on:insufficientFunds={handleInsufficientFunds}
        on:statusChange={handleStatusChange} />
    </div>

    <div class="md:w-1/6 py-2 flex flex-col justify-center">
      {#if timestamp}
        {timestamp}
      {:else}
        <Spinner size={12} />
      {/if}
    </div>

    <div class="hidden md:flex w-1/6 py-2 flex flex-col justify-center">
      <button class="flex justify-end pr-[24px] py-3 link" on:click={openDetails}>
        {$t('transactions.link.view')}
      </button>
    </div>
  </div>
{/if}

<DesktopOrLarger bind:is={isDesktopOrLarger} />

<NftInfoDialog nft={token} bind:modalOpen={nftInfoOpen} viewOnly />

<InsufficientFunds bind:modalOpen={insufficientModal} />

<MobileDetailsDialog
  {token}
  {closeDetails}
  detailsOpen={mobileDetailsOpen}
  selectedItem={item}
  on:insufficientFunds={handleInsufficientFunds}
  on:openModal={handleOpenModal} />

<DesktopDetailsDialog
  detailsOpen={desktopDetailsOpen}
  {closeDetails}
  selectedItem={item}
  on:insufficientFunds={handleInsufficientFunds}
  on:openModal={handleOpenModal} />

<RetryDialog bridgeTx={item} bind:dialogOpen={retryModalOpen} />

<ReleaseDialog bridgeTx={item} bind:dialogOpen={releaseModalOpen} />

<ClaimDialog
  bridgeTx={item}
  bind:loading
  bind:dialogOpen={claimModalOpen}
  nft={token}
  on:claimingDone={() => claimingDone()} />
