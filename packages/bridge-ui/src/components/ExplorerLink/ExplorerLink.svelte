<script lang="ts">
  import type { Address, Hash } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { Icon } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';
  import { shortenAddress } from '$libs/util/shortenAddress';

  type ExplorerCategory = 'address' | 'tx' | 'token';

  export let urlParam: Hash | Address;
  export let chainId: number;

  export let category: ExplorerCategory;
  export let linkText: string | null = null;

  export let shorten: boolean = false;

  $: explorerLink = `${chainConfig[chainId]?.blockExplorers?.default.url}/${category}/${urlParam}`;
</script>

<a href={explorerLink} class={classNames('link f-row gap-1', $$props.class)} target="_blank" rel="noopener noreferrer">
  {#if linkText}
    <span>{linkText}</span>
  {:else}
    {shorten ? shortenAddress(urlParam, 8, 4) : urlParam}
  {/if}
  <Icon size={10} type="arrow-top-right" />
</a>
