<script lang="ts" context="module">
  export const key = Symbol();
</script>

<script lang="ts">
  import { writable } from 'svelte/store';
  import { setContext } from 'svelte';

  export let activeTab = '';

  // State only available to the component and its descendants
  setContext(key, writable(activeTab));
</script>

<div class={$$restProps.class} style={$$restProps.style}>
  <slot />
</div>
