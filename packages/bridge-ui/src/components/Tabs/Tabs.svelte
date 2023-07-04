<script lang="ts" context="module">
  export const key = Symbol();
</script>

<script lang="ts">
  import { getContext, setContext } from 'svelte';
  import { type Writable, writable } from 'svelte/store';

  // Props
  export let activeTab = '';

  // State only available to the component and its descendants
  setContext(key, writable(activeTab));

  // We need to keep the store in sync with the prop in case the user
  // navigates back in the browser, which will change the prop but not
  // the Tabs' state
  const storeActiveTab = getContext<Writable<string>>(key);
  $: $storeActiveTab = activeTab;
</script>

<div class={$$restProps.class} style={$$restProps.style}>
  <slot />
</div>
