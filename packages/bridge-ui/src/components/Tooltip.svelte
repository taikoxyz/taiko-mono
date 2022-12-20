<script lang="ts">
  import TooltipIcon from "./icons/TooltipIcon.svelte";

  export let isOpen: boolean = false;
</script>

<button type="button" on:click={() => (isOpen = true)} class="tooltip-button">
  <TooltipIcon />
</button>
