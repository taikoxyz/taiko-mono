<script lang="ts" context="module">
  import { getContext } from 'svelte';
  import type { Writable } from 'svelte/store';

  export const key = Symbol();
</script>

<script lang="ts">
  import { writable } from 'svelte/store';
  import { setContext } from 'svelte';

  export let activeTab = '';

  // State only available to the component and its descendants
  setContext(key, writable(activeTab));
  const currentActiveTab = getContext<Writable<string>>(key);
  $: $currentActiveTab = activeTab;
</script>

<div class={$$restProps.class} style={$$restProps.style}>
  <slot />
</div>
