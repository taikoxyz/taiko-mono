<script lang="ts">
  import Modal from './Modal.svelte';

  export let title: string;
  export let isOpen: boolean = false;
  export let showXButton: boolean = true;
</script>

<Modal {title} bind:isOpen {showXButton}>
  <div class="flex h-full min-h-tooltip-modal w-full flex-col justify-between">
    <div class="tip-body mb-4 flex-auto">
      <slot name="body" />
    </div>
    <div class="tip-footer self-start">
      <slot name="footer" />
    </div>
  </div>
</Modal>
