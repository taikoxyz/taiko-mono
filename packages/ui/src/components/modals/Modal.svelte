<script lang="ts">
  import X from "../icons/X.svelte";

  export let title: string = null;
  export let isOpen: boolean = false;
  export let onClose: () => void = null;
  export let showXButton: boolean = true;

  const onCloseClicked = () => {
    isOpen = false;
    if (onClose) {
      onClose();
    }
  };
</script>

<div
  class="modal overflow-hidden bg-transparent blur-sm"
  class:modal-open={isOpen}
  on:click|self={onCloseClicked}
>
  <div class="modal-box">
    <h3 class="font-bold text-lg">{title}</h3>
    {#if showXButton}
      <div class="modal-action mt-0">
        <button
          type="button"
          class="cursor-pointer font-sans text-lg"
          on:click={onCloseClicked}
        >
          X
        </button>
      </div>
    {/if}
    <div class="modal-body">
      <slot />
    </div>
  </div>
</div>
