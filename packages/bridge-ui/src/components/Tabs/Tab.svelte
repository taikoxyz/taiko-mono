<script lang="ts">
  import { link } from 'svelte-spa-router';
  import { getContext } from 'svelte';
  import type { Writable } from 'svelte/store';

  export let href: string = '';
  export let name: string = '';

  const activeTab = getContext<Writable<string>>('activeTab');

  $: selected = name === $activeTab;
  $: tabActiveCls = selected ? 'tab-active' : '';
</script>

<a
  role="tab"
  aria-selected={selected}
  class="tab tab-bordered {tabActiveCls}"
  on:click={() => ($activeTab = name)}
  {href}
  use:link>
  <slot />
</a>
