<script lang="ts">
  import { getAccount } from '@wagmi/core';
  import { getContext } from 'svelte';
  import { t } from 'svelte-i18n';
  import { zeroAddress } from 'viem';

  import { Divider } from '$components/core/Divider';
  import InfoRow from '$components/core/InfoRow/InfoRow.svelte';
  import NumberInput from '$components/core/NumberInput/NumberInput.svelte';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import User from '$lib/user';
  import { classNames } from '$lib/util/classNames';
  import { connectedSourceChain } from '$stores/network';
  import { Button } from '$ui/Button';
  import { ProgressBar } from '$ui/ProgressBar';
  import { Spinner } from '$ui/Spinner';

  import Token from '../../lib/token';
  import getConfig from '../../lib/wagmi/getConfig';
  import type { IAddress } from '../../types';
  import { NftRenderer } from '../NftRenderer';
  import {
    counterClasses,
    leftHalfPanel,
    mintContentClasses,
    mintTitleClasses,
    nftRendererWrapperClasses,
    nftRendererWrapperMobileClasses,
    rightHalfPanel,
    supplyClasses,
    wrapperClasses,
  } from './classes';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const buttonClasses = classNames('mt-6');

  $: totalSupply = 0;
  $: mintMax = 0;
  $: progress = Math.floor((totalSupply / 888) * 100);

  $: canMint = false;

  $: freeMintsLeft = 0;

  const mintState = getContext('mint');

  //$: isMinting = false
  $: isReady = false;

  $: freeMintCount = 0;

  $: gasCost = 0;
  $: isCalculating = false;

  $: freeMintCount, calculateGasCost();

  async function calculateGasCost() {
    isCalculating = true;

    gasCost = await Token.estimateMintGasCost({
      freeMintCount,
    });
    isCalculating = false;
  }

  async function load() {
    totalSupply = await Token.totalSupply();
    mintMax = await Token.maxSupply();
    progress = Math.floor((totalSupply / mintMax) * 100);
    isReady = true;

    canMint = await Token.canMint();

    freeMintsLeft = await User.totalWhitelistMintCount();
  }

  connectedSourceChain.subscribe(async () => {
    await load();

    const { config } = getConfig();
    const account = getAccount(config);
    if (!account || !account.address) {
      mintState.set({ ...$mintState, address: zeroAddress });
      return;
    }
    mintState.set({ ...$mintState, address: account.address.toLowerCase() as IAddress });
  });

  async function mint() {
    mintState.set({
      ...$mintState,
      isModalOpen: true,

      isMinting: true,
    });

    // ensure that the input values are numbers
    freeMintCount = parseInt(freeMintCount.toString());

    mintState.set({ ...$mintState, totalMintCount: freeMintCount });
    try {
      const tokenIds = await Token.mint({
        freeMintCount,
        onTransaction: (txHash: string) => {
          mintState.set({ ...$mintState, txHash });
        },
      });
      mintState.set({ ...$mintState, tokenIds });
    } catch (e) {
      console.warn(e);
      //showMintConfirmationModal = false
      mintState.set({ ...$mintState, isModalOpen: false });
    }
    mintState.set({ ...$mintState, isMinting: false });

    await load();
  }
</script>

<div class={wrapperClasses}>
  {#if isReady}
    {#if windowSize !== 'sm'}
      <div class={leftHalfPanel}>
        <div class={nftRendererWrapperClasses}>
          <NftRenderer />
        </div>
      </div>
    {/if}
    <div class={rightHalfPanel}>
      <!-- svelte-ignore missing-declaration -->
      {#if windowSize === 'sm'}
        <div class={nftRendererWrapperMobileClasses}>
          <NftRenderer />
        </div>
      {/if}
      <div class={mintTitleClasses}>{$t('content.mint.title')}</div>

      <p class={mintContentClasses}>
        {$t('content.mint.text')}
      </p>
      <div class="w-full gap-4 flex flex-col">
        <div class={counterClasses}>
          <div class={supplyClasses}>{totalSupply} / {mintMax}</div>
        </div>
        <ProgressBar {progress} />
      </div>

      <NumberInput
        min={0}
        value={canMint ? freeMintsLeft : 0}
        max={freeMintsLeft}
        disabled
        label={$t('content.mint.mintsLeft', {
          values: {
            mintsLeft: canMint ? freeMintsLeft : 0,
          },
        })} />

      <Divider />

      {#if gasCost > 0}
        <div class="w-full gap-4 flex flex-col">
          <InfoRow label="Estimated gas fee" loading={isCalculating} value={`Ξ ${gasCost}`} />
        </div>
      {/if}
      <Button disabled={!canMint} on:click={mint} class={buttonClasses} wide block type="primary">
        {$t('buttons.mint')}</Button>
    </div>
  {:else}
    <Spinner size="lg" />
  {/if}
</div>

<ResponsiveController bind:windowSize />
