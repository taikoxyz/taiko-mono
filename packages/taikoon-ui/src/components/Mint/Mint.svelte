<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { getContext } from 'svelte';
  import { t } from 'svelte-i18n';
  import { zeroAddress } from 'viem';

  import { Divider } from '$components/core/Divider';
  import InfoRow from '$components/core/InfoRow/InfoRow.svelte';
  import { errorToast } from '$components/core/Toast';
  import { web3modal } from '$lib/connect';
  import Token from '$lib/token';
  import User from '$lib/user';
  import { classNames } from '$lib/util/classNames';
  import { account } from '$stores/account';
  import type { IMint } from '$stores/mint';
  import { Button } from '$ui/Button';
  import { ProgressBar } from '$ui/ProgressBar';
  import { Spinner } from '$ui/Spinner';

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

  $: totalSupply = -1;
  $: mintMax = -1;
  $: progress = 0;

  $: canMint = false;

  const mintState = getContext<IMint>('mint');

  $: isReady = false;

  $: totalMintCount = -1;

  $: gasCost = 0;
  $: isCalculating = false;

  async function calculateGasCost() {
    isCalculating = true;
    gasCost = await Token.estimateMintGasCost($mintState.address);
    isCalculating = false;
  }

  function reset() {
    canMint = false;
    mintState.set({ ...$mintState, address: zeroAddress, totalMintCount: -1 });
  }

  async function load() {
    if (isReady && (!$account || ($account && !$account.isConnected))) {
      return reset();
    }
    isReady = false;

    if (totalSupply < 0 && mintMax < 0) {
      totalSupply = await Token.totalSupply();
      mintMax = await Token.maxSupply();
      progress = Math.floor((totalSupply / mintMax) * 100);
    }

    if (!$account || !$account.address || $account.address === zeroAddress) {
      isReady = true;
      return reset();
    }
    const address = $account.address as IAddress;

    const balance = await Token.balanceOf(address);
    hasAlreadyMinted = balance > 0;

    if (totalMintCount < 0) {
      totalMintCount = await User.totalWhitelistMintCount(address);
    }

    await calculateGasCost();

    mintState.set({ ...$mintState, totalMintCount });

    if (!hasAlreadyMinted) {
      canMint = await Token.canMint(address);
    }

    if (!canMint) {
      mintState.set({ ...$mintState, totalMintCount, address: address.toLowerCase() as IAddress });
      isReady = true;
      return;
    }

    mintState.set({ ...$mintState, totalMintCount, address: address.toLowerCase() as IAddress });

    isReady = true;
  }

  $: $account, load();
  $: hasAlreadyMinted = false;

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
      console.error(e);
      mintState.set({ ...$mintState, isModalOpen: false });
      if (
        e.shortMessage &&
        e.shortMessage ===
          'The total cost (gas * gas fee + value) of executing this transaction exceeds the balance of the account.'
      ) {
        e.shortMessage = 'You do not have enough ETH to cover the minting cost, please bridge some ETH to Taiko.';
      }
      console.error('mint error', e.name);
      errorToast({
        title: 'Mint Error',
        message: e.shortMessage || e.message,
      });
    }
    mintState.set({ ...$mintState, isMinting: false });
    await load();
  }

  let web3modalOpen = false;

  function connectWallet() {
    if (web3modalOpen) return;
    web3modal.open();
  }
</script>

<div class={wrapperClasses}>
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
    {#if isReady}
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
      {:else if $account && !$account.isConnected}
        <Divider />

        <div class={classNames('text-xl', 'text-center')}>
          {$t('content.mint.connectWallet')}
        </div>

        <Button class={buttonClasses} on:click={connectWallet} wide block type="primary">
          {$t('buttons.connectWallet')}</Button>
      {:else if !canMint && $mintState.totalMintCount === 0}
        <Divider />

        <div class={classNames('text-xl', 'text-center')}>
          {$t('content.mint.notEligible')}
        </div>

        <Button disabled class={buttonClasses} wide block type="primary">
          {$t('buttons.mint')}</Button>
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

        <Button on:click={mint} class={buttonClasses} wide block type="primary">
          {$t('buttons.mint')}</Button>
      {/if}
    {:else}
      <Spinner size="lg" />
    {/if}
  </div>
</div>

<ResponsiveController bind:windowSize />
