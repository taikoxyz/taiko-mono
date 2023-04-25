<script lang="ts">
  import { onMount } from 'svelte'

  type Closeable = 'button' | 'outside'

  export let open = false
  export let closeable: Closeable | undefined
  export let title = ''

  let modal: HTMLElement

  onMount(() => {
    if (closeable === 'outside') {
      // Close modal when clicking outside the modal box
      const onModalClick = (event: MouseEvent) => {
        if (event.target === event.currentTarget) {
          open = false
        }
      }

      modal.addEventListener('click', onModalClick)

      return () => {
        modal.removeEventListener('click', onModalClick)
      }
    }
  })
</script>

<div class="modal" class:modal-open={open} bind:this={modal}>
  <div class="modal-box">
    {#if closeable === 'button'}
      <button class="btn btn-sm btn-circle absolute right-2 top-2" on:click={() => (open = false)}>
        ✕
      </button>
    {/if}

    {#if title}
      <h3 class="text-lg font-bold">{title}</h3>
    {/if}

    <div class="content">
      <slot />
    </div>
  </div>
</div>
