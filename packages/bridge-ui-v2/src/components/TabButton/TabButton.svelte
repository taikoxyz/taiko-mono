<script lang="ts">
  import { onDestroy, onMount } from 'svelte';

  import { Button } from '$components/Button';
  import { activeTab, checkIsActive } from '$stores/bridgetabs';

  export let tabName = '';

  let activeTabName: string;
  const unsubscribe = activeTab.subscribe((value) => {
    activeTabName = value;
  });

  onDestroy(() => {
    unsubscribe();
  });
  $: classes = `w-full mr-2 p-3 rounded-full flex ${activeTabName === tabName ? 'btn-primary' : 'btn-ghost'}`;
</script>

<Button class={classes} on:click={() => activeTab.set(tabName)}>
  <slot />
</Button>
