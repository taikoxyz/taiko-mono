<script lang="ts">
  export let title = '';
</script>

<dialog class="modal">
  <div class="modal-box relative p-10 bg-primary-base-background">
    <h3 class="title-section-bold mb-2 text-primary-base-content">{title}</h3>
    <slot />
  </div>

  <div class="overlay-backdrop" />
</dialog>
