<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { CloseButton } from '$components/Button';
  import { errorToast, warningToast } from '$components/NotificationToast';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import { getProofReceiptForMsgHash } from '$libs/bridge/getProofReceiptForMsgHash';
  import type { BridgeTransaction, GetProofReceiptResponse } from '$libs/bridge/types';
  import {
    InsufficientBalanceError,
    InvalidProofError,
    NotConnectedError,
    ProcessMessageError,
    RetryError,
  } from '$libs/error';
  import { uid } from '$libs/util/uid';

  import { DialogStep, DialogStepper } from '../Stepper';
  import Claim from './Claim.svelte';
  import ClaimStepNavigation from './ClaimStepNavigation.svelte';
  import ClaimConfirmStep from './ClaimSteps/ClaimConfirmStep.svelte';
  import ClaimInfoStep from './ClaimSteps/ClaimInfoStep.svelte';
  import ClaimReviewStep from './ClaimSteps/ClaimReviewStep.svelte';
  import { ClaimSteps } from './types';

  const dialogId = `dialog-${uid()}`;
  const dispatch = createEventDispatcher();

  export let dialogOpen = false;

  export let loading = false;
  export const handleClaimClick = async () => {
    ClaimComponent.claim();
  };

  const handleAccountChange = () => {
    activeStep = ClaimSteps.INFO;
  };

  let claimingDone = false;

  let proofReceipt: GetProofReceiptResponse;

  const closeDialog = () => {
    dialogOpen = false;
    reset();
  };

  let ClaimComponent: Claim;

  export let activeStep: ClaimSteps = ClaimSteps.INFO;

  export let item: BridgeTransaction;

  //TODO: update this to display info alongside toasts
  const handleClaimError = (event: CustomEvent<{ error: Error }>) => {
    const err = event.detail;
    switch (true) {
      case err instanceof NotConnectedError:
        warningToast({ title: $t('messages.account.required') });
        break;
      case err instanceof UserRejectedRequestError:
        warningToast({ title: $t('transactions.actions.claim.rejected.title') });
        break;
      case err instanceof InsufficientBalanceError:
        dispatch('insufficientFunds', { tx: item });
        break;
      case err instanceof InvalidProofError:
        errorToast({ title: $t('common.error'), message: $t('bridge.errors.invalid_proof_provided') });
        break;
      case err instanceof ProcessMessageError:
        errorToast({ title: $t('bridge.errors.process_message_error') });
        break;
      case err instanceof RetryError:
        errorToast({ title: $t('bridge.errors.retry_error') });
        break;
      default:
        errorToast({
          title: $t('bridge.errors.unknown_error.title'),
          message: $t('bridge.errors.unknown_error.message'),
        });
        break;
    }
  };

  const reset = () => {
    activeStep = ClaimSteps.INFO;
  };

  let canContinue = false;

  $: if (dialogOpen) {
    getProofReceiptForMsgHash({
      msgHash: item.hash,
      srcChainId: item.srcChainId,
      destChainId: item.destChainId,
    }).then((reciepts) => {
      proofReceipt = reciepts;
    });
  }
</script>

<dialog id={dialogId} class="modal" class:modal-open={dialogOpen}>
  <div class="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute md:min-h-[600px]">
    <CloseButton onClick={closeDialog} />
    <div class="w-full h-full f-col">
      <h3 class="title-body-bold mb-7">Claim your assets</h3>
      <DialogStepper>
        <DialogStep stepIndex={ClaimSteps.INFO} currentStepIndex={activeStep} isActive={activeStep === ClaimSteps.INFO}
          >Prerequisites</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.REVIEW}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.REVIEW}>{$t('bridge.step.review.title')}</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.CONFIRM}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.CONFIRM}>{$t('bridge.step.confirm.title')}</DialogStep>
      </DialogStepper>

      {#if activeStep === ClaimSteps.INFO}
        <ClaimInfoStep tx={item} bind:canContinue />
      {:else if activeStep === ClaimSteps.REVIEW}
        <ClaimReviewStep tx={item} {proofReceipt} />
      {:else if activeStep === ClaimSteps.CONFIRM}
        <ClaimConfirmStep tx={item} on:claim={handleClaimClick} />
      {/if}

      <div class="f-col text-left gap-4 self-end w-full absolute bottom-0 left-0 px-[24px] py-[35px]">
        <ClaimStepNavigation
          bind:activeStep
          bind:loading
          bind:canContinue
          on:closeDialog={closeDialog}
          bind:claimingDone />
      </div>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>

<Claim
  bind:bridgeTx={item}
  bind:this={ClaimComponent}
  on:error={handleClaimError}
  claiming={loading}
  bind:claimingDone />

<OnAccount change={handleAccountChange} />
