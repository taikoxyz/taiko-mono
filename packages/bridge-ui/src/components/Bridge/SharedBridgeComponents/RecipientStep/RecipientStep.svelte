<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { ProcessingFee, Recipient } from '$components/Bridge/SharedBridgeComponents';

  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

  export let hasEnoughEth: boolean = false;
  export let needsManualRecipientConfirmation = false;

  export const reset = () => {
    recipientComponent?.clearRecipient();
    processingFeeComponent?.resetProcessingFee();
  };
</script>

<div class="mt-[30px] space-y-[16px]">
  <Recipient bind:this={recipientComponent} />
  <ProcessingFee bind:this={processingFeeComponent} bind:hasEnoughEth />
</div>
<div class="h-sep my-[30px]" />

{#if needsManualRecipientConfirmation}
  <Alert type="warning">{$t('bridge.alerts.smart_contract_wallet')}</Alert>
{/if}
