<script lang="ts">
  import { t } from 'svelte-i18n';

  import { calculatingProcessingFee, importDone } from '$components/Bridge/state';
  import { BridgeSteps, BridgingStatus } from '$components/Bridge/types';
  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { StepBack } from '$components/Stepper';
  import { account, connectedSmartContractWallet } from '$stores/account';

  export let activeStep: BridgeSteps = BridgeSteps.IMPORT;
  export let validatingImport = false;

  export let hasEnoughFundsToContinue: boolean;
  export let needsManualReviewConfirmation: boolean;
  export let needsManualRecipientConfirmation: boolean;
  export let bridgingStatus: BridgingStatus;

  export let exceedsQuota: boolean;

  let nextStepButtonText: string;
  let manuallyConfirmedReviewStep = false;
  let manuallyConfirmedRecipientStep = false;

  const getStepText = () => {
    if (activeStep === BridgeSteps.REVIEW) {
      return $t('common.confirm');
    }
    if (activeStep === BridgeSteps.CONFIRM) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  const handleNextStep = () => {
    if (activeStep === BridgeSteps.IMPORT) {
      if ($connectedSmartContractWallet && !manuallyConfirmedRecipientStep) {
        // If the user is connected to a smart contract wallet and hasn't confirmed the risk, we enforce the recipient step first
        activeStep = BridgeSteps.RECIPIENT;
      } else {
        activeStep = BridgeSteps.REVIEW;
      }
    } else if (activeStep === BridgeSteps.REVIEW) {
      activeStep = BridgeSteps.CONFIRM;
    } else if (activeStep === BridgeSteps.RECIPIENT) {
      activeStep = BridgeSteps.REVIEW;
    } else if (activeStep === BridgeSteps.CONFIRM) {
      activeStep = BridgeSteps.IMPORT;
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === BridgeSteps.REVIEW) {
      activeStep = BridgeSteps.IMPORT;
    } else if (activeStep === BridgeSteps.CONFIRM) {
      activeStep = BridgeSteps.REVIEW;
    } else if (activeStep === BridgeSteps.RECIPIENT) {
      activeStep = BridgeSteps.REVIEW;
    }
    reset();
  };

  const reset = () => {
    manuallyConfirmedReviewStep = false;
    manuallyConfirmedRecipientStep = false;
  };

  $: disabled = !$account || !$account.isConnected || $calculatingProcessingFee;

  $: nextStepButtonText = getStepText();

  $: reviewConfirmed = !needsManualReviewConfirmation || manuallyConfirmedReviewStep;

  $: recipientConfirmed = !needsManualRecipientConfirmation || manuallyConfirmedRecipientStep;
</script>

<div class="f-col w-full justify-content-center gap-4">
  {#if activeStep === BridgeSteps.IMPORT}
    <div class="h-sep mt-0" />
    <ActionButton
      priority="primary"
      disabled={!$importDone || disabled || exceedsQuota}
      loading={validatingImport}
      on:click={() => handleNextStep()}>
      <span class="body-bold">{nextStepButtonText}</span>
    </ActionButton>
  {/if}

  {#if activeStep === BridgeSteps.REVIEW}
    {#if needsManualReviewConfirmation}
      <ActionButton
        priority="primary"
        disabled={manuallyConfirmedReviewStep}
        on:click={() => (manuallyConfirmedReviewStep = true)}>
        {#if !reviewConfirmed}
          {$t('bridge.actions.acknowledge')}
        {:else}
          <Icon type="check" />{$t('common.confirmed')}
        {/if}
      </ActionButton>
    {/if}

    <ActionButton
      priority="primary"
      disabled={disabled || !reviewConfirmed || !hasEnoughFundsToContinue}
      on:click={() => handleNextStep()}>
      <span class="body-bold">{nextStepButtonText}</span>
    </ActionButton>

    <StepBack on:click={() => handlePreviousStep()}>
      {$t('common.back')}
    </StepBack>
  {/if}

  {#if activeStep === BridgeSteps.RECIPIENT}
    {#if needsManualRecipientConfirmation}
      <ActionButton
        priority="primary"
        disabled={recipientConfirmed}
        on:click={() => (manuallyConfirmedRecipientStep = true)}>
        {#if !recipientConfirmed}
          {$t('bridge.actions.acknowledge')}
        {:else}
          <Icon type="check" />{$t('common.confirmed')}
        {/if}
      </ActionButton>
    {/if}
    <ActionButton disabled={disabled || !recipientConfirmed} priority="primary" on:click={() => handleNextStep()}>
      <span class="body-bold">{nextStepButtonText}</span>
    </ActionButton>
  {/if}

  {#if activeStep === BridgeSteps.CONFIRM}
    {#if bridgingStatus === BridgingStatus.DONE}
      <ActionButton {disabled} priority="primary" on:click={() => handleNextStep()}>
        <span class="body-bold">{nextStepButtonText}</span>
      </ActionButton>
    {:else}
      <StepBack on:click={() => handlePreviousStep()}>
        {$t('common.back')}
      </StepBack>
    {/if}
  {/if}
</div>
