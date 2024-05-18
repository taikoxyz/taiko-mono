<script lang="ts">
  import { getContext } from 'svelte';

  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { classNames } from '$lib/util/classNames';
  import type { ITaikoonDetail } from '$stores/taikoonDetail';

  import { NftRenderer } from '../NftRenderer';
  import { filterFormWrapperClasses, taikoonsWrapperClasses, titleClasses, wrapperClasses } from './classes';
  import { default as TaikoonDetail } from './TaikoonDetail.svelte';

  export let tokenIds: number[] = [];
  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  export let title: string = 'The Collection';

  export let isLoading = false;
  const taikoonDetailState = getContext<ITaikoonDetail>('taikoonDetail');

  $: selectedTaikoonId = -1;

  async function onRouteChange() {
    const hash = location.hash;
    const taikoonId = parseInt(hash.replace('#', ''));
    if (isNaN(taikoonId)) return;
    selectedTaikoonId = taikoonId;
    taikoonDetailState.set({
      ...$taikoonDetailState,
      tokenId: taikoonId,
      isModalOpen: true,
    });
  }
</script>

<svelte:window on:hashchange={onRouteChange} />

<div class={wrapperClasses}>
  {#if windowSize !== 'sm'}
    <TaikoonDetail {isLoading} taikoonId={selectedTaikoonId} />
  {/if}
  <div class="flex flex-col w-full h-full">
    <div class={filterFormWrapperClasses}>
      <div class={titleClasses}>{title}</div>
    </div>
    <div class={taikoonsWrapperClasses}>
      {#each tokenIds as tokenId}
        <a
          href={`#${tokenId}`}
          class={classNames('w-full', 'rounded-xl', 'lg:rounded-3xl', 'md:rounded-2xl', 'overflow-hidden')}>
          <NftRenderer size="full" {tokenId} />
        </a>
      {/each}
    </div>
  </div>
</div>

<ResponsiveController bind:windowSize />
