<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';
  import { StepBack } from '$components/Stepper';

  import { ReleaseSteps } from './types';

  const dispatch = createEventDispatcher();

  export let activeStep: ReleaseSteps;
  export let loading = false;
  export let canContinue = false;
  export let releasingDone = false;
  export let releasing = false;
  export let hideContinueButton: boolean;

  const INITIAL_STEP = ReleaseSteps.CHECK;

  const getNextStepText = (step: ReleaseSteps) => {
    if (step === ReleaseSteps.REVIEW) {
      return $t('common.confirm');
    }
    if (step === ReleaseSteps.CONFIRM) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  const getPrevStepText = (step: ReleaseSteps) => {
    if (step === INITIAL_STEP) {
      return $t('common.cancel');
    }
    return $t('common.back');
  };

  const handleNextStep = () => {
    if (activeStep === INITIAL_STEP) {
      activeStep = ReleaseSteps.REVIEW;
    } else if (activeStep === ReleaseSteps.REVIEW) {
      activeStep = ReleaseSteps.CONFIRM;
    } else if (activeStep === ReleaseSteps.CONFIRM) {
      dispatch('closeDialog');
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === INITIAL_STEP) {
      dispatch('closeDialog');
    }
    if (activeStep === ReleaseSteps.REVIEW) {
      activeStep = ReleaseSteps.CHECK;
    } else if (activeStep === ReleaseSteps.CONFIRM) {
      activeStep = ReleaseSteps.REVIEW;
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
    (activeStep === ReleaseSteps.CHECK && !canContinue) ||
    (activeStep === ReleaseSteps.CONFIRM && !releasingDone);
</script>

{#if (activeStep !== ReleaseSteps.CONFIRM || releasingDone) && (activeStep !== ReleaseSteps.CHECK || canContinue) && !hideContinueButton}
  <div class="h-sep" />
  <ActionButton onPopup priority="primary" disabled={isNextStepDisabled} {loading} on:click={handleNextStep}>
    {nextStepButtonText}
  </ActionButton>
{/if}
{#if !releasingDone && !releasing}
  <StepBack on:click={handlePreviousStep}>{prevStepButtonText}</StepBack>
{/if}
