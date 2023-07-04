<script lang="ts">
  import TooltipModal from '../TooltipModal.svelte';

  export let show: boolean;
</script>

<TooltipModal title="Waiting for Relayer" bind:isOpen={show}>
  <span slot="body">
    <div class="text-left">
      <strong>
        Please wait for the relayer to claim the transaction for you.
      </strong>

      This will happen automatically. Depending on network congestion, this can
      take up to several hours.
    </div>
  </span>
</TooltipModal>
