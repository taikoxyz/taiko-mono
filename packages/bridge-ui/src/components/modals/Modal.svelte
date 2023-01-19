<script lang="ts">
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

<svelte:window
  on:keydown={function (e) {
    if (e.key === "Escape") {
      onCloseClicked();
    }
  }}
/>

<div class="modal bg-black/60" class:modal-open={isOpen}>
  <div class="modal-box bg-dark-2">
    <h3 class="font-bold text-lg text-center mt-4">{title}</h3>
    {#if showXButton}
      <div class="modal-action mt-0">
        <button
          type="button"
          class="btn btn-sm btn-circle absolute right-2 top-2 cursor-pointer font-sans text-lg"
          on:click={onCloseClicked}
        >
          &times;
        </button>
      </div>
    {/if}
    <div class="modal-body">
      <slot />
    </div>
  </div>
</div>

<style>
  .modal {
    align-items: center;
  }
</style>
