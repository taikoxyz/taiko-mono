<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { getContext } from 'svelte';
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import ActionButton from '$components/Button/ActionButton.svelte';
  import { Divider } from '$components/core/Divider';
  import InfoRow from '$components/core/InfoRow/InfoRow.svelte';
  import { ProgressBar } from '$components/core/ProgressBar';
  import { Link } from '$components/core/Text';
  import { classNames } from '$lib/util/classNames';
  import type { IMint } from '$stores/mint';
  import { Spinner } from '$ui/Spinner';

  import {
    counterClasses,
    currentMintedClasses,
    infoRowClasses,
    maxMintedClasses,
    mintContentClasses,
    mintTitleClasses,
  } from './classes';

  const dispatch = createEventDispatcher();

  export let isReady: boolean = false;
  export let totalSupply = 0;
  export let gasCost = 0;
  export let mintMax = 0;
  export let isCalculating = false;
  export let progress = 0;
  export let buttonLabel: string | null = null;

  const mintState = getContext<IMint>('mint');
  const buttonClasses = classNames('mt-6 max-h-[56px]');

  let windowSize: 'sm' | 'md' | 'lg' = 'md';
</script>

<div class={classNames('w-full', 'h-full')}>
  <!-- svelte-ignore missing-declaration -->

  <div class={mintTitleClasses}>{$t('content.mint.title')}</div>

  <p class={mintContentClasses}>
    {$t('content.mint.textTop')}
  </p>

  <p class={mintContentClasses}>
    {$t('content.mint.textBottom')}

    <Link href="https://trailblazers.taiko.xyz/" target="_blank">{$t('content.mint.textTrailblazers')}</Link>
  </p>

  <div class={infoRowClasses}>
    <div class={counterClasses}>
      <div class={currentMintedClasses}>#{totalSupply}</div>
      <div class={maxMintedClasses}>/ {mintMax}</div>
    </div>
    <ProgressBar {progress} />
  </div>

  {#if !buttonLabel}
    <Divider />

    <div class={infoRowClasses}>
      <InfoRow label={$t('content.mint.totalMints')} value={$mintState.totalMintCount.toString()} />
      <InfoRow label={$t('content.mint.gasFee')} loading={isCalculating} value={`Ξ ${gasCost}`} />
    </div>
  {/if}

  <ActionButton
    priority="primary"
    on:click={async () => {
      dispatch('mint');
    }}
    disabled={!isReady}
    class={buttonClasses}
    onPopup>
    {#if isReady}
      {#if buttonLabel}
        {buttonLabel}
      {:else}
        {$t('buttons.mint')}
      {/if}
    {:else}
      <Spinner size="sm" />
    {/if}
  </ActionButton>
</div>

<ResponsiveController bind:windowSize />
