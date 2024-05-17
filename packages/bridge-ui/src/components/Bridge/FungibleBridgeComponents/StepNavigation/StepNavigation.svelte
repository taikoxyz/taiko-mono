<script lang="ts">
  import { t } from 'svelte-i18n';

  import { importDone } from '$components/Bridge/state';
  import { BridgeSteps, BridgingStatus } from '$components/Bridge/types';
  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { StepBack } from '$components/Stepper';
  import { account } from '$stores/account';

  export let activeStep: BridgeSteps = BridgeSteps.IMPORT;
  export let validatingImport = false;

  export let needsManualConfirmation: boolean;
  export let bridgingStatus: BridgingStatus;

  let nextStepButtonText: string;

  let manuallyConfirmed = false;

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
      activeStep = BridgeSteps.REVIEW;
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
    manuallyConfirmed = false;
  };

  $: disabled = !$account || !$account.isConnected;

  $: {
    nextStepButtonText = getStepText();
  }

  $: needsConfirmation = needsManualConfirmation && !manuallyConfirmed;
</script>

<div class="f-col w-full justify-content-center gap-4">
  {#if activeStep === BridgeSteps.IMPORT}
    <div class="h-sep mt-0" />
    <ActionButton
      priority="primary"
      disabled={!$importDone || disabled}
      loading={validatingImport}
      on:click={() => handleNextStep()}>
      <span class="body-bold">{nextStepButtonText}</span>
    </ActionButton>
  {/if}
  {#if activeStep === BridgeSteps.REVIEW}
    {#if needsManualConfirmation}
      <ActionButton priority="primary" disabled={manuallyConfirmed} on:click={() => (manuallyConfirmed = true)}>
        {#if needsConfirmation}
          {$t('bridge.actions.acknowledge')}
        {:else}
          <Icon type="check" />{$t('common.confirmed')}
        {/if}
      </ActionButton>
    {/if}

    <ActionButton priority="primary" disabled={disabled || needsConfirmation} on:click={() => handleNextStep()}>
      <span class="body-bold">{nextStepButtonText}</span>
    </ActionButton>

    <StepBack on:click={() => handlePreviousStep()}>
      {$t('common.back')}
    </StepBack>
  {/if}

  {#if activeStep === BridgeSteps.RECIPIENT}
    <ActionButton {disabled} priority="primary" on:click={() => handleNextStep()}>
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
