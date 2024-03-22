<script lang="ts">
  import type { Address, Hash } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { classNames } from '$libs/util/classNames';

  type ExplorerCategory = 'address' | 'transaction' | 'token';

  export let urlParam: Hash | Address;
  export let chainId: number;

  export let category: ExplorerCategory;

  $: explorerLink = `${chainConfig[chainId]?.blockExplorers?.default.url}/${category}/${urlParam}`;
</script>

<a href={explorerLink} class={classNames('link', $$props.class)} target="_blank" rel="noopener noreferrer">
  <slot />
</a>
