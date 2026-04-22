<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { getAccount } from '@wagmi/core';
  import { getContext, onMount } from 'svelte';
  import { zeroAddress } from 'viem';

  import { errorToast } from '$components/core/Toast';
  import { web3modal } from '$lib/connect';
  import User from '$lib/user';
  import type { IMint } from '$stores/mint';
  import { connectedSourceChain } from '$stores/network';
  import { Spinner } from '$ui/Spinner';

  import Token from '../../lib/token';
  import getConfig from '../../lib/wagmi/getConfig';
  import { account } from '../../stores/account';
  import type { IAddress } from '../../types';
  import { NftRenderer } from '../NftRenderer';
  import { leftHalfPanel, nftRendererWrapperMobileClasses, rightHalfPanel, wrapperClasses } from './classes';
  import { default as EligibilityPanel } from './EligibilityPanel.svelte';
  import { default as MintForm } from './MintForm.svelte';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  $: canMint = false;
  $: totalSupply = 0;
  $: mintMax = 0;
  $: progress = Math.floor((totalSupply / mintMax) * 100);

  const mintState = getContext<IMint>('mint');

  $: isReady = false;
  $: isConnected = false;
  $: totalMintCount = 0;

  $: gasCost = 0;
  $: isCalculating = false;

  $: isMinting = false;

  $: $account, (isConnected = Boolean($account && $account.address));

  async function calculateGasCost() {
    try {
      if (!isReady || isCalculating || !canMint) return;
      isCalculating = true;

      gasCost = await Token.estimateMintGasCost();

      isCalculating = false;
    } catch (e) {
      console.warn(e);
      isCalculating = false;
    }
  }

  $: hasMinted = false;

  async function load() {
    try {
      canMint = await Token.canMint();
      mintMax = await Token.maxSupply();
      totalSupply = await Token.totalSupply();
      hasMinted = await Token.hasMinted();
      if (!canMint) {
        isReady = true;
        return;
      }
      totalMintCount = await User.totalWhitelistMintCount();
      isReady = true;
    } catch (e: any) {
      errorToast({
        title: 'Load error',
        message: e.message,
      });
    }
  }

  onMount(async () => {
    if (isReady) return;
    await load();
  });

  connectedSourceChain.subscribe(async () => {
    if (isReady) return;

    const { config } = getConfig();
    const account = getAccount(config);

    if (!account || !account.address) {
      mintState.set({ ...$mintState, address: zeroAddress });
      isReady = true;
      return;
    }

    await load();
    if (!canMint) return;
    await calculateGasCost();
    mintState.set({ ...$mintState, totalMintCount, address: account.address.toLowerCase() as IAddress });
  });

  $: txHash = '';

  async function mint() {
    isMinting = true;

    totalMintCount = parseInt(totalMintCount.toString());

    try {
      await Token.mint({
        freeMintCount: totalMintCount,
        onTransaction: (tx: string) => {
          txHash = tx;
        },
      });
    } catch (e) {
      console.warn(e);
      return;
    }

    await load();

    mintStep = 2;
  }

  async function view() {
    window.location.href = `https://taikoscan.io/tx/${txHash}`;
  }
  let web3modalOpen = false;

  async function connect() {
    if (web3modalOpen) return;
    web3modal.open();
  }

  $: mintStep = 0;
</script>

<div class={wrapperClasses}>
  {#if windowSize !== 'sm'}
    <div class={leftHalfPanel}>
      <NftRenderer />
    </div>
  {/if}
  <div class={rightHalfPanel}>
    {#if windowSize === 'sm'}
      <div class={nftRendererWrapperMobileClasses}>
        <NftRenderer />
      </div>
    {/if}

    {#if !isConnected}
      <MintForm
        on:mint={connect}
        {totalSupply}
        {gasCost}
        {mintMax}
        {isCalculating}
        {progress}
        buttonLabel="Connect Wallet"
        isReady={isReady && !isMinting} />
    {:else if isReady && (canMint || mintStep > 0)}
      {#if mintStep === 0}
        <EligibilityPanel
          disabled={false}
          on:click={async () => {
            mintStep = 1;
          }}
          step="eligible" />
      {:else if mintStep === 1}
        <MintForm
          on:mint={mint}
          {totalSupply}
          {gasCost}
          {mintMax}
          {isCalculating}
          {progress}
          isReady={isReady && !isMinting} />
      {:else}
        <EligibilityPanel on:click={view} disabled={false} step="success" />
      {/if}
    {:else if hasMinted}
      <EligibilityPanel on:click={view} disabled={false} step="success" />
    {:else if isReady && !canMint}
      <EligibilityPanel step="non-eligible" />
    {:else}
      <Spinner />
    {/if}
  </div>
</div>

<ResponsiveController bind:windowSize />
