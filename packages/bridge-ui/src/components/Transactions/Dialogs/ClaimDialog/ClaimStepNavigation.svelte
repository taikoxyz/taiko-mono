<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';

  import { ActionButton } from '$components/Button';

  import { ClaimSteps } from './types';

  const dispatch = createEventDispatcher();

  export let activeStep: ClaimSteps;
  export let loading = false;
  export let canContinue = false;
  export let claimingDone = false;

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

  $: isNextStepEnabled = !canContinue || loading || (activeStep === ClaimSteps.CONFIRM && !claimingDone);
</script>

<div class="f-row gap-2 mt-[20px]">
  {#if !claimingDone}
    <ActionButton onPopup priority="secondary" disabled={loading} on:click={handlePreviousStep}
      >{prevStepButtonText}</ActionButton>
  {/if}
  <ActionButton onPopup priority="primary" disabled={isNextStepEnabled} {loading} on:click={handleNextStep}
    >{nextStepButtonText}</ActionButton>
</div>
