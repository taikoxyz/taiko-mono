<script lang="ts">
  import { getContext } from 'svelte';
  import type { Writable } from 'svelte/store';

  import { key, subKey } from './Tabs.svelte';

  export let tab: string = '';

  export let type: string = 'main';

  let activeTab;
  if (type == 'main') {
    activeTab = getContext<Writable<string>>(key);
  } else {
    activeTab = getContext<Writable<string>>(subKey);
  }

  $: selected = tab === $activeTab;
  $: classes = `${$$restProps.class || ''} ${!selected ? 'hidden' : ''}`;
</script>

<div role="tabpanel" aria-expanded={selected} class={classes}>
  <slot />
</div>

<style lang="postcss">
  [role='tabpanel'] {
    @apply w-full;
  }
</style>
