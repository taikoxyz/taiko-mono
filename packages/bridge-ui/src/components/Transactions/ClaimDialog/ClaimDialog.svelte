<script lang="ts">
  import { t } from 'svelte-i18n';

  import { CloseButton } from '$components/Button';
  import type { BridgeTransaction } from '$libs/bridge/types';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { uid } from '$libs/util/uid';

  import DialogStep from './DialogStep.svelte';
  import DialogStepper from './DialogStepper.svelte';

  const dialogId = `dialog-${uid()}`;
  export let dialogOpen = false;

  const closeDialog = () => {
    dialogOpen = false;
  };

  const enum ClaimSteps {
    INFO,
    REVIEW,
    CONFIRM,
  }

  // const enum ClaimStatus {
  //   PENDING,
  //   INITIAL,
  //   FINAL,
  // }
  export let activeStep: ClaimSteps = ClaimSteps.INFO;
  // export let validatingImport = false;

  // export let claimStatus: ClaimStatus;

  export let item: BridgeTransaction;

  let nextStepButtonText: string;

  const getStepText = () => {
    if (activeStep === ClaimSteps.INFO) {
      return $t('common.confirm');
    }
    if (activeStep === ClaimSteps.REVIEW) {
      return $t('common.ok');
    } else {
      return $t('common.continue');
    }
  };

  const handleNextStep = () => {
    if (activeStep === ClaimSteps.INFO) {
      activeStep = ClaimSteps.REVIEW;
    } else if (activeStep === ClaimSteps.REVIEW) {
      activeStep = ClaimSteps.CONFIRM;
    } else if (activeStep === ClaimSteps.CONFIRM) {
      activeStep = ClaimSteps.INFO;
    }
  };

  const handlePreviousStep = () => {
    if (activeStep === ClaimSteps.REVIEW) {
      activeStep = ClaimSteps.INFO;
    } else if (activeStep === ClaimSteps.CONFIRM) {
      activeStep = ClaimSteps.REVIEW;
    }
  };

  // $: disabled = !$account || !$account.isConnected;

  // $: showStepNavigation = true;

  $: {
    nextStepButtonText = getStepText();
  }
</script>

<dialog
  id={dialogId}
  class="modal"
  class:modal-open={dialogOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: dialogOpen, callback: closeDialog, uuid: dialogId }}>
  <div class="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute">
    <CloseButton onClick={closeDialog} />
    {item}
    <div class="w-full">
      <h3 class="title-body-bold mb-7">{$t('token_dropdown.label')}</h3>
      <DialogStepper on:click={() => handlePreviousStep()}>
        <DialogStep stepIndex={ClaimSteps.INFO} currentStepIndex={activeStep} isActive={activeStep === ClaimSteps.INFO}
          >{$t('bridge.step.import.title')}</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.REVIEW}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.REVIEW}>{$t('bridge.step.review.title')}</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.CONFIRM}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.CONFIRM}>{$t('bridge.step.confirm.title')}</DialogStep>
      </DialogStepper>
      <p>
        Lorem ipsum dolor sit amet consectetur adipisicing elit. A inventore, beatae aliquid quidem consectetur fuga?
        Inventore ab dolorum reprehenderit possimus quidem voluptatem, rem repellat, laudantium fugit doloribus
        aspernatur esse perferendis!
      </p>
      <div class="f-col text-left">
        <button on:click={handleNextStep} class="btn btn-primary mt-5">{nextStepButtonText}</button>
        <button on:click={handlePreviousStep} class="link mt-5 ml-3">{$t('common.back')}</button>
      </div>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>
