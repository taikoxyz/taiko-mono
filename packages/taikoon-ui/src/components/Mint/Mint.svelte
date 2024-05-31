<script lang="ts">
  import { getAccount } from '@wagmi/core';
  import { getContext } from 'svelte';
  import { t } from 'svelte-i18n';
  import { zeroAddress } from 'viem';

  import { Divider } from '$components/core/Divider';
  import InfoRow from '$components/core/InfoRow/InfoRow.svelte';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { errorToast } from '$components/core/Toast';
  import User from '$lib/user';
  import { classNames } from '$lib/util/classNames';
  import type { IMint } from '$stores/mint';
  import { Button } from '$ui/Button';
  import { ProgressBar } from '$ui/ProgressBar';
  import { Spinner } from '$ui/Spinner';

  import Token from '../../lib/token';
  import getConfig from '../../lib/wagmi/getConfig';
  import { account } from '../../stores/account';
  import type { IAddress } from '../../types';
  import { NftRenderer } from '../NftRenderer';
  import {
    counterClasses,
    currentMintedClasses,
    eligibilityLabelClasses,
    eligibilityValueClasses,
    infoRowClasses,
    leftHalfPanel,
    maxMintedClasses,
    mintContentClasses,
    mintTitleClasses,
    nftRendererWrapperClasses,
    nftRendererWrapperMobileClasses,
    rightHalfPanel,
    wrapperClasses,
  } from './classes';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const buttonClasses = classNames('mt-6');

  $: totalSupply = 0;
  $: mintMax = 0;
  $: progress = Math.floor((totalSupply / 888) * 100);

  $: canMint = false;

  const mintState = getContext<IMint>('mint');

  $: isReady = false;

  $: totalMintCount = 0;

  $: gasCost = 0;
  $: isCalculating = false;

  $: totalMintCount, calculateGasCost();

  async function calculateGasCost() {
    isCalculating = true;

    gasCost = await Token.estimateMintGasCost();
    isCalculating = false;
  }

  async function load() {
    totalSupply = await Token.totalSupply();
    mintMax = await Token.maxSupply();
    progress = Math.floor((totalSupply / mintMax) * 100);
    isReady = true;

    canMint = await Token.canMint();
    if (!canMint) {
      return;
    }
    totalMintCount = await User.totalWhitelistMintCount();
  }

  $: $account, postLoad();
  $: mintedTokenIds = [] as number[];
  $: hasAlreadyMinted = false;

  async function postLoad() {
    await load();
    isReady = false;
    const { config } = getConfig();
    const account = getAccount(config);
    if (!account || !account.address) {
      canMint = false;
      totalMintCount = 0;
      gasCost = 0;
      mintState.set({ ...$mintState, totalMintCount, address: zeroAddress });
      isReady = true;
      return;
    }

    mintedTokenIds = await Token.tokenOfOwner(account.address);
    hasAlreadyMinted = mintedTokenIds.length > 0;
    mintState.set({ ...$mintState, totalMintCount, address: account.address.toLowerCase() as IAddress });
    isReady = true;
  }

  async function mint() {
    mintState.set({
      ...$mintState,
      isModalOpen: true,

      isMinting: true,
    });

    // ensure that the input values are numbers
    totalMintCount = parseInt(totalMintCount.toString());

    mintState.set({ ...$mintState, totalMintCount: totalMintCount });
    try {
      const tokenIds = await Token.mint({
        freeMintCount: totalMintCount,
        onTransaction: (txHash: string) => {
          mintState.set({ ...$mintState, txHash });
        },
      });
      mintState.set({ ...$mintState, tokenIds });
    } catch (e: any) {
      console.warn(e);
      //showMintConfirmationModal = false
      mintState.set({ ...$mintState, isModalOpen: false });
      errorToast({
        title: 'Mint Error',
        message: e.message,
      });
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
      <div class={infoRowClasses}>
        <div class={counterClasses}>
          <div class={currentMintedClasses}>#{totalSupply}</div>
          <div class={maxMintedClasses}>/ {mintMax}</div>
        </div>
        <ProgressBar {progress} />
      </div>

      {#if hasAlreadyMinted && $account.address}
        <Divider />

        <div class={classNames('text-xl', 'text-center')}>
          {$t('content.mint.alreadyMinted')}
        </div>

        <Button href={`/collection/${$account.address.toLowerCase()}`} class={buttonClasses} wide block type="primary">
          {$t('buttons.yourTaikoons')}</Button>
      {:else}
        <div class={counterClasses}>
          <div class={eligibilityLabelClasses}>{$t('content.mint.eligibleLabel')}</div>
          <div class={eligibilityValueClasses}>{$mintState.totalMintCount}</div>
        </div>

        <Divider />

        <div class={infoRowClasses}>
          <InfoRow label="Total mints" value={$mintState.totalMintCount.toString()} />
          <InfoRow label="Gas fee" loading={isCalculating} value={`Ξ ${gasCost}`} />
        </div>

        <Button
          disabled={!canMint || $mintState.totalMintCount === 0}
          on:click={mint}
          class={buttonClasses}
          wide
          block
          type="primary">
          {$t('buttons.mint')}</Button>
      {/if}
    </div>
  {:else}
    <Spinner size="lg" />
  {/if}
</div>

<ResponsiveController bind:windowSize />
