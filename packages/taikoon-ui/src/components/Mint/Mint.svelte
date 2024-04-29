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
  import { H1, H4 } from '$ui/Text';

  import Token from '../../lib/token';
  import getConfig from '../../lib/wagmi/getConfig';
  import type { IAddress } from '../../types';
  import { NftRenderer } from '../NftRenderer';

  const wrapperClasses = classNames(
    'h-max',
    'w-full',
    'flex',
    'md:flex-row',
    'flex-col',
    'items-center',
    'justify-center',
    'md:px-5',
    'p-2',
    'gap-8',
    'md:py-16',
  );

  const halfPanel = classNames(
    'h-full',
    'md:w-max',
    'flex flex-col',
    'items-center',
    'justify-center',
    'gap-2',
    'bg-neutral-background',
    'rounded-3xl',
    'p-8',
    'w-full',
  );

  const mintState = getContext('mint');

  const leftHalfPanel = classNames(halfPanel, 'aspect-square');

  const rightHalfPanel = classNames(halfPanel, 'md:px-12', 'md:max-w-[500px]');

  const counterClasses = classNames(
    'w-full',
    'flex',
    'flex-row',
    'items-center',
    'justify-between',
    'font-sans',
    'font-bold',
    'mt-6',
  );

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const buttonClasses = classNames('mt-6');

  $: totalSupply = 0;
  $: mintMax = 0;
  $: progress = Math.floor((totalSupply / 888) * 100);

  $: canMint = false;

  $: freeMintsLeft = 0;

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
        <div class="rounded-3xl overflow-hidden">
          <NftRenderer />
        </div>
      </div>
    {/if}
    <div class={rightHalfPanel}>
      {#if windowSize === 'sm'}
        <div class="rounded-3xl my-8 overflow-hidden">
          <NftRenderer />
        </div>
      {/if}
      <H1 class="w-full text-left">{$t('content.mint.title')}</H1>

      <p class="font-normal font-sans text-content-secondary">
        {$t('content.mint.text')}
      </p>
      <div class="w-full gap-4 flex flex-col">
        <div class={counterClasses}>
          <H4>{totalSupply} / {mintMax}</H4>
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
