<script lang="ts">
  import { setContext } from 'svelte';

  export let activeTab = '';

  setContext('activeTab', activeTab);
</script>

<div class={$$restProps.class}>
  <slot />
</div>
