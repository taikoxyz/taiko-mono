<script lang="ts">
  import { t } from 'svelte-i18n';

  import { ImportMethod, NFTSteps } from '$components/Bridge/types';
  import { ActionButton } from '$components/Button';

  import { selectedImportMethod } from '../ImportStep/state';

  export let canProceed = false;
  export let activeStep: NFTSteps = NFTSteps.IMPORT;
  export let validatingImport = false;

  let nextStepButtonText: string;

  const nextStep = () => (activeStep = Math.min(activeStep + 1, NFTSteps.CONFIRM));
  // const previousStep = () => (activeStep = Math.max(activeStep - 1, NFTSteps.IMPORT));

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

  const handlePreviousStep = () => {};

  $: {
    nextStepButtonText = getStepText();
  }
</script>

<div class="f-col w-full justify-content-center gap-4">
  {#if activeStep === NFTSteps.IMPORT}
    {#if $selectedImportMethod !== ImportMethod.NONE}
      <ActionButton priority="primary" disabled={!canProceed} loading={validatingImport} on:click={nextStep}
        ><span class="body-bold">{nextStepButtonText}</span></ActionButton>

      <button on:click={() => ($selectedImportMethod = ImportMethod.NONE)} class="flex justify-center py-3 link">
        {$t('common.back')}
      </button>
    {/if}
  {/if}
  {#if activeStep === NFTSteps.REVIEW}
    <ActionButton priority="primary" disabled={!canProceed} on:click={nextStep}
      ><span class="body-bold">{nextStepButtonText}</span></ActionButton>

    <button on:click={() => handlePreviousStep} class="flex justify-center py-3 link">
      {$t('common.back')}
    </button>
  {/if}

  {#if activeStep === NFTSteps.CONFIRM}
    <ActionButton priority="primary" disabled={!canProceed} on:click={nextStep}
      ><span class="body-bold">{nextStepButtonText}</span></ActionButton>

    <button on:click={() => handlePreviousStep} class="flex justify-center py-3 link">
      {$t('common.back')}
    </button>
  {/if}
</div>
