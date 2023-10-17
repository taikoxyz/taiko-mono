<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { formatEther, formatUnits } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { Icon } from '$components/Icon';
  import { type BridgeTransaction, MessageStatus } from '$libs/bridge';
  import { TokenType } from '$libs/token';

  import ChainSymbolName from './ChainSymbolName.svelte';
  import InsufficientFunds from './InsufficientFunds.svelte';
  import MobileDetailsDialog from './MobileDetailsDialog.svelte';
  import Status from './Status.svelte';

  export let item: BridgeTransaction;

  const dispatch = createEventDispatcher();
  let insufficientModal = false;
  let detailsOpen = false;
  let isDesktopOrLarger = false;

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

  let attrs = isDesktopOrLarger ? {} : { role: 'button' };
</script>

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
      {:else if item.tokenType === TokenType.ERC721}
        {item.amount}
      {:else if item.tokenType === TokenType.ERC1155}
        {item.amount}
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

<DesktopOrLarger bind:is={isDesktopOrLarger} />

<MobileDetailsDialog {closeDetails} {detailsOpen} selectedItem={item} on:insufficientFunds={handleInsufficientFunds} />

<InsufficientFunds bind:modalOpen={insufficientModal} />
