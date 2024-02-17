<script lang="ts">
  import { t } from 'svelte-i18n';

  import { LoadingMask } from '$components/LoadingMask';
  import type { NFT } from '$libs/token';
  import { connectedSourceChain } from '$stores/network';

  import { NFTCardGrid } from './NFTCards';
  import { NFTList } from './NFTList';
  import { NFTView } from './types';

  export let loading: boolean;

  export let viewOnly = false;

  export let nfts: NFT[] | null = [];

  export let nftView: NFTView = NFTView.LIST;

  $: size = nfts?.length && nfts?.length > 2 ? 'max-h-[350px] min-h-[350px]' : 'max-h-[249px] min-h-[249px]';

  $: outerClasses = 'relative m bg-neutral rounded-[20px] overflow-hidden ' + size;
  $: innerClasses = 'overflow-y-auto p-[24px] ' + size;
</script>

<div class={outerClasses}>
  <div class={innerClasses}>
    {#if loading}
      <LoadingMask spinnerClass="border-white" text={$t('messages.bridge.nft_scanning')} />
    {:else if nftView === NFTView.LIST && nfts}
      <NFTList bind:nfts chainId={$connectedSourceChain?.id} {viewOnly} />
    {:else if nftView === NFTView.CARDS && nfts}
      <NFTCardGrid bind:nfts {viewOnly} />
    {/if}
  </div>
</div>
