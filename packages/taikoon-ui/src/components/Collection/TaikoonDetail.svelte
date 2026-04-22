<script lang="ts">
  import { scale } from 'svelte/transition';
  import { t } from 'svelte-i18n';

  import { Icons } from '$components/core/Icons';
  import { InfoRow } from '$components/core/InfoRow';
  import { shortenAddress } from '$lib/util/shortenAddress';
  import { Chip } from '$ui/Chip';
  import { Spinner } from '$ui/Spinner';

  import Token from '../../lib/token';
  import type { IAddress } from '../../types';
  import { NftRenderer } from '../NftRenderer';
  import { chipWrapperClasses, detailClasses, detailContainerClasses, detailTitleClasses } from './classes';

  export let isLoading = false;
  export let taikoonId: number = -1;

  $: shortenedAddress = '...';
  $: owner = '0x0' as IAddress;
  async function updateShortenedAddress() {
    if (taikoonId < 0) return;
    owner = await Token.ownerOf(taikoonId);
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
            window.location.hash = '';
          }}
          class="my-2 bg-transparent"
          size="14" />
      </div>

      <NftRenderer class="mb-2" size="lg" tokenId={taikoonId} />
      <div class={chipWrapperClasses}>
        <Chip>{$t('content.collection.labels.minted')}</Chip>
      </div>

      <p class={detailTitleClasses}>
        Taikoon #{taikoonId}
      </p>

      <div class={detailContainerClasses}>
        <InfoRow label={$t('content.collection.ownedBy')} value={shortenedAddress} href={`/collection/${owner}`} />
      </div>
    {/if}
  </div>
{/if}
