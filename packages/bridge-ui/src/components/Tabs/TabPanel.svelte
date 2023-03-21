<script lang="ts">
  import { getContext } from 'svelte';
  import type { Writable } from 'svelte/store';

  export let tab: string = '';

  const activeTab = getContext<Writable<string>>('activeTab');

  $: selected = tab === $activeTab;
  $: classes = `${$$restProps.class || ''} ${!selected ? 'hidden' : ''}`;
</script>

<div role="tabpanel" aria-expanded={selected} class={classes}>
  <slot />
</div>
