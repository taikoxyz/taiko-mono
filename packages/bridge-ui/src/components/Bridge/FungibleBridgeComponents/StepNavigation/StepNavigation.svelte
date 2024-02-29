<script lang="ts">
  import { t } from 'svelte-i18n';

  import { importDone } from '$components/Bridge/state';
  import { BridgeSteps, BridgingStatus } from '$components/Bridge/types';
  import { ActionButton } from '$components/Button';
  import { StepBack } from '$components/Stepper';
  import { account } from '$stores/account';

  export let activeStep: BridgeSteps = BridgeSteps.IMPORT;
  export let validatingImport = false;

  export let bridgingStatus: BridgingStatus;

  let nextStepButtonText: string;

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
  };

  $: disabled = !$account || !$account.isConnected;

  $: showStepNavigation = true;

  $: {
    nextStepButtonText = getStepText();
  }
</script>

{#if showStepNavigation}
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
      <ActionButton priority="primary" {disabled} on:click={() => handleNextStep()}>
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
{/if}
