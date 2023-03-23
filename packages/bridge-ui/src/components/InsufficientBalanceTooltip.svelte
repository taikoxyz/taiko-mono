<script lang="ts">
  import TooltipModal from './modals/TooltipModal.svelte';

  export let show: boolean;
</script>

<TooltipModal title="Insufficient Balance" bind:isOpen={show}>
  <span slot="body">
    <div class="text-left">
      You have insufficient balance to claim this transaction. <strong
        >Please wait for the relayer to claim the transaction for you.</strong>
    </div>
  </span>
</TooltipModal>
