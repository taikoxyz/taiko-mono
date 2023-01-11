<script lang="ts">
  import Tooltip from "./Tooltip.svelte";

  export let onClick: () => void;
</script>

<div class="label-text flex items-center">
  <slot name="buttonText"></slot>
  <button
    class="inline-block cursor-pointer ml-1"
    on:click={onClick}
  >
    <Tooltip />
  </button>
</div>
