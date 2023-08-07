<script lang="ts" context="module">
  export const key = Symbol();
  export const subKey = Symbol();
</script>

<script lang="ts">
  import { getContext, setContext } from 'svelte';
  import { type Writable, writable } from 'svelte/store';

  // Props
  export let activeTab = '';
  export let activeSubTab = '';
  export let type = '';

  let t = 'main';
  let k = key;

  if (type == 'sub') {
    k = subKey;
    t = activeSubTab;
  } else {
    k = key;
    t = activeTab;
  }

  // State only available to the component and its descendants
  setContext(k, writable(t));

  // We need to keep the store in sync with the prop in case the user
  // navigates back in the browser, which will change the prop but not
  // the Tabs' state
  const storeActiveTab = getContext<Writable<string>>(k);
  $: $storeActiveTab = t;
</script>

<div class={$$restProps.class} style={$$restProps.style}>
  <slot />
</div>
