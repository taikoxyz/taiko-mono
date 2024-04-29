<script lang="ts">
  import { scale } from 'svelte/transition';
  import { t } from 'svelte-i18n';

  import { Icons } from '$components/core/Icons';
  import { InfoRow } from '$components/core/InfoRow';
  import { classNames } from '$lib/util/classNames';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { Chip } from '$ui/Chip';
  import { Spinner } from '$ui/Spinner';

  import Token from '../../lib/token';
  import { NftRenderer } from '../NftRenderer';

  export let isLoading = false;
  export let taikoonId: number = -1;

  const detailClasses = classNames(
    'bg-neutral-background',
    'py-5',
    'px-10',
    'gap-3',
    'flex',
    'flex-col',
    'items-center',
    'justify-start',
    'rounded-t-3xl',
    'h-full',
    'w-96',
  );

  const detailContainerClasses = classNames(
    'w-full',
    'flex',
    'gap-3',
    'my-2',
    'flex-col',
    'items-center',
    'justify-start',
  );

  $: shortenedAddress = '...';

  async function updateShortenedAddress() {
    if (taikoonId < 0) return;
    const owner = await Token.ownerOf(taikoonId);
    shortenedAddress = await shortenAddress(owner);
  }

  $: taikoonId, updateShortenedAddress();
</script>

{#if taikoonId >= 0}
  <div transition:scale={{ duration: 300 }} class={detailClasses}>
    {#if isLoading}
      <Spinner />
    {:else}
      <div class="flex flex-row w-full justify-end">
        <Icons.XSolid
          withEvents
          on:click={() => {
            taikoonId = -1;
          }}
          class="my-2 bg-transparent"
          size="14" />
      </div>

      <NftRenderer class="mb-2" size="lg" tokenId={taikoonId} />
      <div class="my-2 flex flex-row w-full justify-start">
        <Chip>{$t('content.collection.labels.minted')}</Chip>
      </div>

      <p class="my-2 text-left w-full text-5xl font-clash-grotesk font-semibold">
        Taikoon #{taikoonId}
      </p>

      <div class={detailContainerClasses}>
        <InfoRow
          label={$t('content.collection.ownedBy')}
          value={shortenedAddress}
          href={'/collection/${taikoon.owner}'} />
      </div>
    {/if}
  </div>
{/if}
