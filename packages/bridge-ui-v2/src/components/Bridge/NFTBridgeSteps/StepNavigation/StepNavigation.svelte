<script lang="ts">
  import { t } from 'svelte-i18n';

  import { importDone } from '$components/Bridge/state';
  import { ImportMethod, NFTSteps } from '$components/Bridge/types';
  import { ActionButton } from '$components/Button';

  import { selectedImportMethod } from '../ImportStep/state';
  import StepBack from './StepBack.svelte';

  export let activeStep: NFTSteps = NFTSteps.IMPORT;
  export let validatingImport = false;

  let nextStepButtonText: string;

  // const nextStep = () => (activeStep = Math.min(activeStep + 1, NFTSteps.CONFIRM));

  const getStepText = () => {
    if (activeStep === NFTSteps.REVIEW) {
      return $t('common.confirm');
    }
    if (activeStep === NFTSteps.CONFIRM) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  const handleNextStep = () => {
    if (activeStep === NFTSteps.IMPORT) {
      activeStep = NFTSteps.REVIEW;
    } else if (activeStep === NFTSteps.REVIEW) {
      activeStep = NFTSteps.CONFIRM;
    } else if (activeStep === NFTSteps.RECIPIENT) {
      activeStep = NFTSteps.REVIEW;
    } else if (activeStep === NFTSteps.CONFIRM) {
      activeStep = NFTSteps.IMPORT;
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === NFTSteps.REVIEW) {
      activeStep = NFTSteps.IMPORT;
    } else if (activeStep === NFTSteps.CONFIRM) {
      activeStep = NFTSteps.REVIEW;
    }
  };

  $: showStepNavigation = $selectedImportMethod !== ImportMethod.NONE;

  $: {
    nextStepButtonText = getStepText();
  }
</script>

{#if showStepNavigation}
  <div class="f-col w-full justify-content-center gap-4">
    {#if activeStep === NFTSteps.IMPORT}
      {#if $selectedImportMethod !== ImportMethod.NONE}
        <ActionButton
          priority="primary"
          disabled={!$importDone}
          loading={validatingImport}
          on:click={() => handleNextStep()}>
          <span class="body-bold">{nextStepButtonText}</span>
        </ActionButton>

        <StepBack on:click={() => ($selectedImportMethod = ImportMethod.NONE)}>{$t('common.back')}</StepBack>
      {/if}
    {/if}
    {#if activeStep === NFTSteps.REVIEW}
      <ActionButton priority="primary" on:click={() => handleNextStep()}>
        <span class="body-bold">{nextStepButtonText}</span>
      </ActionButton>

      <StepBack on:click={() => handlePreviousStep()}>
        {$t('common.back')}
      </StepBack>
    {/if}

    {#if activeStep === NFTSteps.RECIPIENT}
      <ActionButton priority="primary" on:click={() => handleNextStep()}>
        <span class="body-bold">{nextStepButtonText}</span>
      </ActionButton>

      <StepBack on:click={() => handlePreviousStep()}>
        {$t('common.back')}
      </StepBack>
    {/if}

    {#if activeStep === NFTSteps.CONFIRM}
      <!-- <ActionButton priority="primary" disabled={!canProceed} on:click={() => handleNextStep()}>
        <span class="body-bold">{nextStepButtonText}</span>
      </ActionButton> -->

      <StepBack on:click={() => handlePreviousStep()}>
        {$t('common.back')}
      </StepBack>
    {/if}
  </div>
{/if}
