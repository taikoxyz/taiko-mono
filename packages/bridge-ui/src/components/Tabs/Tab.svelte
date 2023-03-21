<script lang="ts">
  import { link } from 'svelte-spa-router';
  import { setContext, getContext } from 'svelte';

  export let href: string = '';
  export let name: string = '';

  const activeTab = getContext('activeTab');

  $: selected = name === activeTab;
  $: tabActive = selected ? 'tab-active' : '';
</script>

<a
  role="tab"
  aria-selected={selected}
  class="tab tab-bordered {tabActive}"
  on:click={() => setContext('activeTab', name)}
  {href}
  use:link>
  <slot />
</a>
