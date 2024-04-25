<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { StepBack } from '$components/Stepper';

  import { INITIAL_STEP, RetrySteps } from './types';

  const dispatch = createEventDispatcher();

  export let activeStep: RetrySteps;
  export let loading = false;
  export let canContinue = false;
  export let retryDone = false;
  export let retrying = false;

  const getNextStepText = (step: RetrySteps) => {
    if (step === RetrySteps.REVIEW) {
      return $t('common.confirm');
    }
    if (step === RetrySteps.CONFIRM) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  const getPrevStepText = (step: RetrySteps) => {
    if (step === INITIAL_STEP) {
      return $t('common.cancel');
    }
    return $t('common.back');
  };

  const handleNextStep = () => {
    if (activeStep === INITIAL_STEP) {
      activeStep = RetrySteps.REVIEW;
    } else if (activeStep === RetrySteps.REVIEW) {
      activeStep = RetrySteps.CONFIRM;
    } else if (activeStep === RetrySteps.CONFIRM) {
      dispatch('closeDialog');
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === INITIAL_STEP) {
      dispatch('closeDialog');
    }
    if (activeStep === RetrySteps.REVIEW) {
      activeStep = RetrySteps.SELECT;
    } else if (activeStep === RetrySteps.CONFIRM) {
      activeStep = RetrySteps.REVIEW;
    }
  };

  $: nextStepButtonText = getNextStepText(activeStep);
  $: prevStepButtonText = getPrevStepText(activeStep);

  $: if (activeStep) {
    getPrevStepText(activeStep);
    getNextStepText(activeStep);
  }

  $: isNextStepEnabled = !canContinue || loading || (activeStep === RetrySteps.CONFIRM && !retryDone);
</script>

{#if activeStep !== RetrySteps.CONFIRM}
  <div class="h-sep" />
  <ActionButton onPopup priority="primary" disabled={isNextStepEnabled} {loading} on:click={handleNextStep}
    >{nextStepButtonText}</ActionButton>
{:else if activeStep === RetrySteps.CONFIRM && retryDone}
  <ActionButton onPopup priority="primary" disabled={isNextStepEnabled} {loading} on:click={handleNextStep}
    >{nextStepButtonText}</ActionButton>
{/if}
{#if !retryDone && !retrying}
  <StepBack on:click={handlePreviousStep}>{prevStepButtonText}</StepBack>
{/if}
