<script lang="ts">
  import { getContext } from 'svelte';
  import type { Writable } from 'svelte/store';

  import { key } from './Tabs.svelte';

  export let tab: string = '';

  const activeTab = getContext<Writable<string>>(key);

  $: selected = tab === $activeTab;
  $: classes = `${$$restProps.class || ''} ${!selected ? 'hidden' : ''}`;
</script>

<div role="tabpanel" class={classes}>
  <slot />
</div>

<style lang="postcss">
  [role='tabpanel'] {
    @apply w-full;
  }
</style>
