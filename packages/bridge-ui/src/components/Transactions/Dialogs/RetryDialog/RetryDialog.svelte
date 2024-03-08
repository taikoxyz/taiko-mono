<script lang="ts">
  import { t } from 'svelte-i18n';

  import { CloseButton } from '$components/Button';
  import { DialogStep, DialogStepper } from '$components/Transactions/Dialogs/Stepper';
  import type { BridgeTransaction } from '$libs/bridge';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { uid } from '$libs/util/uid';

  export let dialogOpen = false;

  export let item: BridgeTransaction;

  const dialogId = `dialog-${uid()}`;

  const closeDialog = () => {
    dialogOpen = false;
  };

  const enum ClaimSteps {
    INFO,
    REVIEW,
    CONFIRM,
  }

  export let activeStep: ClaimSteps = ClaimSteps.INFO;

  let nextStepButtonText: string;

  // const getStepText = () => {
  //   if (activeStep === ClaimSteps.INFO) {
  //     return $t('common.confirm');
  //   }
  //   if (activeStep === ClaimSteps.REVIEW) {
  //     return $t('common.ok');
  //   } else {
  //     return $t('common.continue');
  //   }
  // };

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
</script>

<dialog
  id={dialogId}
  class="modal"
  class:modal-open={dialogOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: dialogOpen, callback: closeDialog, uuid: dialogId }}>
  <div class="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute">
    <CloseButton onClick={closeDialog} />
    <div class="w-full">
      <h3 class="title-body-bold mb-7">{$t('token_dropdown.label')}</h3>
      {item}
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
