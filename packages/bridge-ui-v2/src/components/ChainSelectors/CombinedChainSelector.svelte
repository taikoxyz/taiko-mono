<script lang="ts">
  import { switchNetwork } from '@wagmi/core';
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Chain, SwitchChainError, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { destNetwork } from '$components/Bridge/state';
  import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
  import { LoadingMask } from '$components/LoadingMask';
  import { warningToast } from '$components/NotificationToast';
  import { OnNetwork } from '$components/OnNetwork';
  import { chainIdToChain } from '$libs/chain';
  import { getAlternateNetwork } from '$libs/network';
  import { truncateString } from '$libs/util/truncateString';
  import { network } from '$stores/network';

  import ChainsDialog from './ChainsDialog.svelte';
  import ChainsDropdown from './ChainsDropdown.svelte';
  import SwitchChainsButton from './SwitchChainsButton.svelte';

  let sourceToggled = false;
  let destinationToggled = false;
  let switchingNetwork = false;
  let isDesktopOrLarger = false;

  let iconSize = 'min-w-[24px] max-w-[24px] min-h-[24px] max-h-[24px]';

  async function selectChain(event: CustomEvent<{ chain: Chain; switchWallet: boolean }>) {
    const { chain, switchWallet } = event.detail;

    if (switchWallet) {
      switchingNetwork = true;
      try {
        await switchNetwork({ chainId: chain.id });
      } catch (err) {
        console.error(err);
        if (err instanceof SwitchChainError) {
          warningToast({
            title: $t('messages.network.pending.title'),
            message: $t('messages.network.pending.message'),
          });
        }
        if (err instanceof UserRejectedRequestError) {
          warningToast({
            title: $t('messages.network.rejected.title'),
            message: $t('messages.network.rejected.message'),
          });
        }
      } finally {
        switchingNetwork = false;
      }
    } else {
      $destNetwork = chain;
    }
  }

  const onNetworkChange = () => setAlternateNetwork();

  const setAlternateNetwork = () => {
    const alternateChainID = getAlternateNetwork();
    if (alternateChainID) {
      $destNetwork = chainIdToChain(alternateChainID);
    }
  };

  const onSourceToggle = () => (sourceToggled = !sourceToggled);

  const onDestinationToggle = () => (destinationToggled = !destinationToggled);

  $: selectClasses = `select bg-transparent appearance-none w-full py-[12px] px-[15px]  focus:border-transparent focus:outline-none focus:bg-primary-background-hover`;

  $: containerClasses = `${
    destinationToggled && isDesktopOrLarger ? 'rounded-t-[10px]' : 'rounded-[10px]'
  } f-col w-full relative bg-neutral-background `;

  $: srcChain = $network;
  $: destChain = $destNetwork;

  onMount(() => {
    const alternateChainID = getAlternateNetwork();
    if (!$destNetwork && alternateChainID) {
      // if only two chains are available, set the destination chain to the other one
      $destNetwork = chainIdToChain(alternateChainID);
    }
  });
</script>

<div class={containerClasses}>
  {#if switchingNetwork}
    <LoadingMask spinnerClass="border-white absolute z-20" text={$t('messages.network.switching')} />
  {/if}
  <div class="relative">
    <button on:click={() => onSourceToggle()} class={selectClasses}>
      {#if srcChain}
        {@const icon = chainConfig[Number(srcChain.id)]?.icon || 'Unknown Chain'}
        <div class="f-row items-center gap-2">
          <div class="f-row gap-2 text-right">
            <!-- <span class="text-sm min-w-[40px] text-secondary-content">{$t('common.from')}:</span> -->
            <i role="img" aria-label={srcChain.name}>
              <img src={icon} alt="chain-logo" class="rounded-full {iconSize}" />
            </i>
          </div>
          <span class="text-primary-content text-base">{truncateString(srcChain.name, 8)}</span>
        </div>
      {:else}
        <span class="text-base text-secondary-content"> {$t('chain_selector.from_placeholder')}</span>
      {/if}
    </button>
    {#if isDesktopOrLarger}
      <ChainsDropdown on:change={selectChain} bind:isOpen={sourceToggled} bind:value={srcChain} switchWallet />
    {:else}
      <ChainsDialog on:change={selectChain} bind:isOpen={sourceToggled} value={srcChain} switchWallet />
    {/if}
  </div>

  {#if !switchingNetwork}
    <div class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 z-20">
      <div
        class="bg-neutral-background border-[1px] border-primary-border-dark h-6 w-6 rounded-full flex items-center justify-center">
        <SwitchChainsButton />
      </div>
    </div>
  {/if}

  <div class="relative border-t-[1px] border-primary-border-dark">
    <button on:click={() => onDestinationToggle()} class={selectClasses}>
      {#if destChain}
        {@const icon = chainConfig[Number(destChain.id)]?.icon || 'Unknown Chain'}
        <div class="f-row items-center gap-2">
          <div class="f-row gap-2 text-right">
            <!-- <span class="text-sm min-w-[40px] text-secondary-content">{$t('common.to')}:</span> -->
            <i role="img" aria-label={destChain.name}>
              <img src={icon} alt="chain-logo" class="rounded-full {iconSize}" />
            </i>
          </div>
          <span class="text-primary-content text-base">{truncateString(destChain.name, 8)}</span>
        </div>
      {:else}
        <span class="text-base text-secondary-content"> {$t('chain_selector.to_placeholder')}</span>
      {/if}
    </button>
    {#if isDesktopOrLarger}
      <ChainsDropdown on:change={selectChain} bind:isOpen={destinationToggled} bind:value={destChain} />
    {:else}
      <ChainsDialog on:change={selectChain} bind:isOpen={destinationToggled} value={destChain} />
    {/if}
  </div>
</div>

<OnNetwork change={onNetworkChange} />
<DesktopOrLarger bind:is={isDesktopOrLarger} />
