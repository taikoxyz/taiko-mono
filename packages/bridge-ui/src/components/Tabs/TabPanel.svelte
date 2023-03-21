<script lang="ts">
  import { getContext } from 'svelte';

  export let tab: string = '';

  const activeTab = getContext('activeTab');

  $: selected = tab === activeTab;
  $: classes = `${$$restProps.class || ''} ${!selected ? 'hidden' : ''}`;
</script>

<div role="tabpanel" aria-expanded={selected} class={classes}>
  <slot />
</div>
