<script lang="ts">
  import { getContext } from 'svelte';

  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { classNames } from '$lib/util/classNames';
  import { InputBox } from '$ui/InputBox';
  import { Select } from '$ui/Select';

  import { NftRenderer } from '../NftRenderer';
  import { default as TaikoonDetail } from './TaikoonDetail.svelte';
  export let tokenIds: number[] = [];
  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const wrapperClasses = classNames(
    'h-full',
    'w-full',
    'flex',
    'flex-row',
    'items-start',
    'justify-evenly',
    'pt-36',
    'px-4',
    'gap-10',
    'z-0',
  );

  const taikoonsWrapperClasses = classNames(
    'h-full',
    'z-0',
    'overflow-x-hidden',
    'w-7/10',
    'gap-5',
    'p-5',
    'grid',
    'lg:grid-cols-6',
    'md:grid-cols-4',
    'grid-cols-3',
    'auto-rows-max',
  );

  export let isLoading = false;
  const taikoonDetailState = getContext('taikoonDetail');

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
    <div
      class={classNames(
        'z-10',
        'w-full',
        'flex',
        'flex-col',
        'md:flex-row',
        'md:p-5',
        'gap-5',
        'md:items-center',
        'items-end',
        'justify-between',
      )}>
      <InputBox class="w-full" size="lg" placeholder="Search Taikoons" />

      <Select
        onSelect={(value) => {
          console.warn(value);
        }}
        label="Latest"
        options={[
          {
            label: 'Latest',
            value: 'latest',
          },
          {
            label: 'Oldest',
            value: 'oldest',
          },
          {
            label: 'Most Expensive',
            value: 'mostExpensive',
          },
          {
            label: 'Cheapest',
            value: 'cheapest',
          },
        ]} />
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
