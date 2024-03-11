<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { StepBack } from '$components/Stepper';

  import { ClaimSteps } from './types';

  const dispatch = createEventDispatcher();

  export let activeStep: ClaimSteps;
  export let loading = false;
  export let nextStepDisabled = false;

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
    if (step === ClaimSteps.INFO) {
      return $t('common.cancel');
    }
    return $t('common.back');
  };

  const handleNextStep = () => {
    if (activeStep === ClaimSteps.INFO) {
      activeStep = ClaimSteps.REVIEW;
    } else if (activeStep === ClaimSteps.REVIEW) {
      activeStep = ClaimSteps.CONFIRM;
    } else if (activeStep === ClaimSteps.CONFIRM) {
      dispatch('closeDialog');
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === ClaimSteps.INFO) {
      dispatch('closeDialog');
    }
    if (activeStep === ClaimSteps.REVIEW) {
      activeStep = ClaimSteps.INFO;
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
</script>

{activeStep}

<ActionButton priority="primary" disabled={nextStepDisabled} {loading} on:click={handleNextStep} class="mt-5"
  >{nextStepButtonText} {activeStep}</ActionButton>

<StepBack on:click={handlePreviousStep}>{prevStepButtonText}</StepBack>
