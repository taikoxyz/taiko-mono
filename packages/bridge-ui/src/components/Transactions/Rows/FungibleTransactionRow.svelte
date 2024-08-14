<script lang="ts">
  import { t } from 'svelte-i18n';
  import { formatEther, formatUnits, hexToBigInt } from 'viem';

  import { ClaimDialog, ReleaseDialog, RetryDialog } from '$components/Dialogs';
  import { Spinner } from '$components/Spinner';
  import { DesktopDetailsDialog } from '$components/Transactions/Dialogs';
  import type { BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { getMessageStatusForMsgHash } from '$libs/bridge/getMessageStatusForMsgHash';
  import { TokenType } from '$libs/token';
  import { classNames } from '$libs/util/classNames';
  import { formatTimestamp } from '$libs/util/formatTimestamp';
  import { geBlockTimestamp } from '$libs/util/getBlockTimestamp';
  import { isDesktop, isMobile, isTablet } from '$libs/util/responsiveCheck';
  import { shortenAddress } from '$libs/util/shortenAddress';
  import { account } from '$stores/account';

  import ChainSymbol from '../ChainSymbol.svelte';
  import MobileDetailsDialog from '../Dialogs/MobileDetailsDialog.svelte';
  import InsufficientFunds from '../InsufficientFunds.svelte';
  import { Status } from '../Status';

  export let bridgeTx: BridgeTransaction;
  export let loading = false;
  export let handleTransactionRemoved: (event: CustomEvent) => void;
  export let bridgeTxStatus: Maybe<MessageStatus>;

  let insufficientModal = false;
  let mobileDetailsOpen = false;
  let desktopDetailsOpen = false;

  let timestamp: string;
  const getDate = async () => {
    const blockTimestamp = await geBlockTimestamp(bridgeTx.srcChainId, hexToBigInt(bridgeTx.blockNumber));
    timestamp = formatTimestamp(Number(blockTimestamp));
  };

  const handleOpenClaimModal = (event: CustomEvent) => {
    if (event.detail === 'retry') {
      retryModalOpen = true;
    } else if (event.detail === 'release') {
      releaseModalOpen = true;
    } else if (event.detail === 'claim') {
      claimModalOpen = true;
    }
  };

  const handleInsufficientFunds = () => {
    insufficientModal = true;
  };

  async function handleClaimingDone() {
    // Keeping model and UI in sync
    bridgeTx.msgStatus = await getMessageStatusForMsgHash({
      msgHash: bridgeTx.msgHash,
      srcChainId: Number(bridgeTx.srcChainId),
      destChainId: Number(bridgeTx.destChainId),
    });
    bridgeTxStatus = bridgeTx.msgStatus;
  }

  const openDetails = () => {
    if ($isMobile && !interactiveDialogsOpen) {
      mobileDetailsOpen = true;
    } else if (($isTablet || $isDesktop) && !interactiveDialogsOpen) {
      desktopDetailsOpen = true;
    }
  };

  const handleStatusChange = (event: CustomEvent<MessageStatus>) => {
    bridgeTxStatus = event.detail;
  };

  const closeDetails = () => {
    mobileDetailsOpen = false;
    desktopDetailsOpen = false;
  };

  // Dynamic attributes based on screen size
  $: attrs = $isDesktop ? {} : { role: 'button' };

  // get tx timestamp
  $: $account.isConnected && getDate();

  // Modal states
  $: claimModalOpen = false;
  $: retryModalOpen = false;
  $: releaseModalOpen = false;
  $: interactiveDialogsOpen = claimModalOpen || retryModalOpen || releaseModalOpen;

  // Dynamic classes
  $: commonContainerClasses = classNames(
    'flex text-primary-content md:h-[80px] h-[70px] w-full my-[5px] md:my-[0px] hover:bg-[#C8047D]/10 px-[14px] py-[10px] rounded-[10px]',
  );
  $: desktopContainerClasses = classNames(commonContainerClasses, 'items-center');
  $: tabletContainerClasses = classNames(commonContainerClasses, 'cursor-pointer');
  $: mobileContainerClasses = classNames(commonContainerClasses, 'cursor-pointer dashed-border');

  $: containerClasses = $isDesktop
    ? desktopContainerClasses
    : $isTablet
      ? tabletContainerClasses
      : mobileContainerClasses;

  $: commonColumnClasses = classNames(' relative items-end');
  $: desktopColumnClasses = classNames(commonColumnClasses, 'w-1/6 f-row justify-center items-center');
  $: tabletColumnClasses = classNames(
    commonColumnClasses,
    'w-1/4 f-row  text-left start items-center text-sm space-y-[10px]',
  );
  $: mobileColumnClasses = classNames(commonColumnClasses, 'w-1/3 justify-center f-col text-sm space-y-[10px]');

  $: columnClasses = $isDesktop ? desktopColumnClasses : $isTablet ? tabletColumnClasses : mobileColumnClasses;
</script>

<!-- svelte-ignore a11y-no-static-element-interactions -->
<div class={containerClasses} on:click={openDetails} {...attrs}>
  <!-- Mobile -->
  {#if $isMobile}
    <div class="before-circle"></div>
    <div class="after-circle"></div>
    <div class={`${columnClasses} !items-start pl-[10px]`}>
      <div class="f-row md:hidden">
        <ChainSymbol class="min-w-[24px]" chainId={bridgeTx.srcChainId} />
        {shortenAddress(bridgeTx.message?.from, 4, 3)}
      </div>
      <div class="f-row md:hidden">
        <ChainSymbol class="min-w-[24px]" chainId={bridgeTx.destChainId} />
        {shortenAddress(bridgeTx.message?.to, 4, 3)}
      </div>
    </div>

    <!-- Desktop -->
  {:else if $isDesktop || $isTablet}
    <div class={`${columnClasses}`}>
      <ChainSymbol class="min-w-[24px]" chainId={bridgeTx.srcChainId} />
      {shortenAddress(bridgeTx.message?.from)}
    </div>
    <div class={`${columnClasses} `}>
      <ChainSymbol class="min-w-[24px]" chainId={bridgeTx.destChainId} />
      {shortenAddress(bridgeTx.message?.to)}
    </div>
  {/if}

  <div class={`${columnClasses} items-center`}>
    {#if bridgeTx.tokenType === TokenType.ERC20}
      {formatUnits(bridgeTx.amount ? bridgeTx.amount : BigInt(0), bridgeTx.decimals ?? 0)}
    {:else if bridgeTx.tokenType === TokenType.ETH}
      {formatEther(bridgeTx.amount ? bridgeTx.amount : BigInt(0))}
    {/if}
    {bridgeTx.symbol}
  </div>

  <div class={`${columnClasses}`}>
    <Status
      {bridgeTx}
      on:transactionRemoved={handleTransactionRemoved}
      bind:bridgeTxStatus
      on:openModal={handleOpenClaimModal}
      on:insufficientFunds={handleInsufficientFunds}
      on:statusChange={handleStatusChange} />
  </div>

  {#if $isDesktop}
    <div class={`${columnClasses}  `}>
      {#if timestamp}
        {timestamp}
      {:else}
        <Spinner size={12} />
      {/if}
    </div>

    <div class="flex w-1/6 py-2 flex flex-col justify-center">
      <button class="flex justify-end pr-[24px] py-3 link" on:click={openDetails}>
        {$t('transactions.link.view')}
      </button>
    </div>
  {/if}
</div>

<InsufficientFunds bind:modalOpen={insufficientModal} />

<DesktopDetailsDialog
  detailsOpen={desktopDetailsOpen}
  token={null}
  {closeDetails}
  {bridgeTx}
  on:insufficientFunds={handleInsufficientFunds} />

<MobileDetailsDialog
  detailsOpen={mobileDetailsOpen}
  token={null}
  {closeDetails}
  {bridgeTx}
  on:insufficientFunds={handleInsufficientFunds} />

<RetryDialog {bridgeTx} bind:dialogOpen={retryModalOpen} />

<ReleaseDialog {bridgeTx} bind:dialogOpen={releaseModalOpen} />

<ClaimDialog {bridgeTx} bind:loading bind:dialogOpen={claimModalOpen} on:claimingDone={() => handleClaimingDone()} />

<style>
  .dashed-border {
    position: relative;
    padding-top: 10px;
    padding-bottom: 10px;
  }

  .dashed-border::before {
    content: '';
    position: absolute;
    top: 23px;
    bottom: 20px;
    left: 10;
    border-left: 1px dashed var(--primary-border-dark);
  }

  .before-circle::before {
    content: '';
    position: absolute;
    top: 18px;
    left: 12.5px;
    width: 4px;
    height: 4px;
    border-radius: 50%;
    border: 1px solid var(--primary-border-dark);
    background-color: transparent; /* Keep it transparent */
  }

  .after-circle::after {
    content: '';
    position: absolute;
    bottom: 17px;
    left: 12.5px;
    width: 4px;
    height: 4px;
    border-radius: 50%;
    background-color: var(--primary-border-dark);
  }
</style>
