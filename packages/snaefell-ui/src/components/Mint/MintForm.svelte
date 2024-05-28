<script lang="ts">
    import { ResponsiveController } from '@taiko/ui-lib';
    import { getAccount } from '@wagmi/core';
    import { getContext, onMount } from 'svelte';
    import { t } from 'svelte-i18n';
    import { zeroAddress } from 'viem';

    import ActionButton from '$components/Button/ActionButton.svelte';
    import { Divider } from '$components/core/Divider';
    import InfoRow from '$components/core/InfoRow/InfoRow.svelte';
    import { ProgressBar } from '$components/core/ProgressBar';
    import User from '$lib/user';
    import { classNames } from '$lib/util/classNames';
    import type { IMint } from '$stores/mint';
    import { connectedSourceChain } from '$stores/network';
    import { Spinner } from '$ui/Spinner';

    import Token from '../../lib/token';
    import getConfig from '../../lib/wagmi/getConfig';
    import type { IAddress } from '../../types';
    import { NftRenderer } from '../NftRenderer';
    import {
      counterClasses,
      currentMintedClasses,
      infoRowClasses,
      leftHalfPanel,
      maxMintedClasses,
      mintContentClasses,
      mintTitleClasses,
      nftRendererWrapperMobileClasses,
      rightHalfPanel,
      wrapperClasses,
    } from './classes';

    import { createEventDispatcher } from 'svelte';

const dispatch = createEventDispatcher();



    export let isReady: boolean = false
    export let totalSupply = 0
    export let gasCost = 0
    export let mintMax = 0
    export let isCalculating = false
    export let progress = 0
    const mintState = getContext<IMint>('mint');
        const buttonClasses = classNames('mt-6 max-h-[56px]');

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

</script>
<div class={classNames('w-full', 'h-full')}>
    <!-- svelte-ignore missing-declaration -->
    {#if windowSize === 'sm'}
      <div class={nftRendererWrapperMobileClasses}>
        <NftRenderer />
      </div>
    {/if}

    <div class={mintTitleClasses}>{$t('content.mint.title')}</div>

    <p class={mintContentClasses}>
      {$t('content.mint.textTop')}
    </p>

    <p class={mintContentClasses}>
      {$t('content.mint.textBottom')}
    </p>

    <div class={infoRowClasses}>
      <div class={counterClasses}>
        <div class={currentMintedClasses}>#{totalSupply}</div>
        <div class={maxMintedClasses}>/ {mintMax}</div>
      </div>
      <ProgressBar {progress} />
    </div>

    <Divider />

    <div class={infoRowClasses}>
      <InfoRow label={$t('content.mint.totalMints')} value={$mintState.totalMintCount.toString()} />
      <InfoRow label={$t('content.mint.gasFee')} loading={isCalculating} value={`Ξ ${gasCost}`} />
    </div>

    {#if isReady}
      <ActionButton priority="primary"
      on:click={async () => {
        dispatch('mint');
      }}
      disabled={!isReady} class={buttonClasses} onPopup>
        {$t('buttons.mint')}
      </ActionButton>
    {:else}
      <Spinner />
    {/if}

</div>

<ResponsiveController bind:windowSize />
