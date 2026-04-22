<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { StepBack } from '$components/Stepper';

  import { ClaimSteps } from './types';

  const dispatch = createEventDispatcher();

  export let activeStep: ClaimSteps;
  export let loading = false;
  export let canContinue = false;
  export let claimingDone = false;
  export let claiming = false;
  export let hideContinueButton: boolean;

  const INITIAL_STEP = ClaimSteps.CHECK;

  const getNextStepText = (step: ClaimSteps) => {
    if (step === ClaimSteps.REVIEW) {
      return $t('common.confirm');
    }
    if (step === ClaimSteps.CONFIRM) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  const getPrevStepText = (step: ClaimSteps) => {
    if (step === INITIAL_STEP) {
      return $t('common.cancel');
    }
    return $t('common.back');
  };

  const handleNextStep = () => {
    if (activeStep === INITIAL_STEP) {
      activeStep = ClaimSteps.REVIEW;
    } else if (activeStep === ClaimSteps.REVIEW) {
      activeStep = ClaimSteps.CONFIRM;
    } else if (activeStep === ClaimSteps.CONFIRM) {
      dispatch('closeDialog');
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === INITIAL_STEP) {
      dispatch('closeDialog');
    }
    if (activeStep === ClaimSteps.REVIEW) {
      activeStep = ClaimSteps.CHECK;
    } else if (activeStep === ClaimSteps.CONFIRM) {
      activeStep = ClaimSteps.REVIEW;
    }
  };

  $: nextStepButtonText = getNextStepText(activeStep);
  $: prevStepButtonText = getPrevStepText(activeStep);

  $: if (activeStep) {
    getPrevStepText(activeStep);
    getNextStepText(activeStep);
  }

  $: isNextStepDisabled =
    loading ||
    (activeStep === ClaimSteps.CHECK && !canContinue) ||
    (activeStep === ClaimSteps.CONFIRM && !claimingDone);
</script>

{#if (activeStep !== ClaimSteps.CONFIRM || claimingDone) && !hideContinueButton}
  <div class="h-sep" />
  <ActionButton onPopup priority="primary" disabled={isNextStepDisabled} {loading} on:click={handleNextStep}>
    {nextStepButtonText}
  </ActionButton>
{/if}
{#if !claimingDone && !claiming}
  <StepBack on:click={handlePreviousStep}>{prevStepButtonText}</StepBack>
{/if}
