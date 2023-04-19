<script lang="ts">
  export let open = false
  export let closeable = false
  export let title = 'Modal Title'
</script>

<div class="modal" class:modal-open={open}>
  <div class="modal-box">
    {#if closeable}
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
