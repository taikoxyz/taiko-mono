<script lang="ts">
  export let title: string = null;
  export let isOpen: boolean = false;
  export let showXButton: boolean = true;
  export let onClose: () => void = null;

  const onCloseClicked = () => {
    isOpen = false;
    onClose?.();
  };

  const onWindowKeydownPressed = (event: KeyboardEvent) => {
    if (event.key === 'Escape') {
      onCloseClicked();
    }
  };
</script>

<svelte:window on:keydown={onWindowKeydownPressed} />

<div class="modal bg-black/80" class:modal-open={isOpen}>
  <div class="modal-box">
    <h3 class="font-bold text-lg text-center mt-4">{title}</h3>
    {#if showXButton}
      <div class="modal-action mt-0">
        <button
          type="button"
          class="btn btn-sm btn-circle absolute right-2 top-2 cursor-pointer font-sans text-lg"
          on:click={onCloseClicked}>
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
