<script lang="ts">
  import TooltipModal from "./modals/TooltipModal.svelte";
  import { showMessageStatusTooltip } from '../store/transactions';
</script>

<TooltipModal title="Message Status" bind:isOpen={$showMessageStatusTooltip}>
  <span slot="body">
    <div class="text-left">
      A bridge message will pass through various states:
      <br /><br />
      <ul class="list-disc ml-4">
        <li class="mb-2">
          <strong>Pending</strong>: Your asset is not ready to be bridged. Taiko
          A1 => Ethereum A1 bridging can take several hours before being ready.
          Ethereum A1 => Taiko A1 should be available to claim within minutes.
        </li>
        <li class="mb-2">
          <strong>Claimable</strong>: Your asset is ready to be claimed on the
          destination chain and requires a transaction.
        </li>
        <li class="mb-2">
          <strong>Claimed</strong>: Your asset has finished bridging and is
          available to you on the destination chain.
        </li>
        <li class="mb-2">
          <strong>Retry</strong>: The relayer has failed to process this
          message, and you must retry the processing yourself.
        </li>
        <li class="mb-2">
          <strong>Failed</strong>: Your bridged asset is unable to be processed
          and is available to you on the source chain.
        </li>
      </ul>
    </div>
  </span>
</TooltipModal>
