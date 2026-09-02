<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { ContractFunctionExecutionError, type Hash, UserRejectedRequestError } from 'viem';

  import { CloseButton } from '$components/Button';
  import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
  import Claim from '$components/Dialogs/Claim.svelte';
  import { errorToast, warningToast } from '$components/NotificationToast/NotificationToast.svelte';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import type { BridgeTransaction } from '$libs/bridge/types';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import {
    InsufficientBalanceError,
    InvalidProofError,
    NotConnectedError,
    ProcessMessageError,
    RetryError,
  } from '$libs/error';
  import type { NFT } from '$libs/token';
  import { getLogger } from '$libs/util/logger';

  import { ClaimConfirmStep, ReviewStep } from '../Shared';
  import ClaimPreCheck from '../Shared/ClaimPreCheck.svelte';
  import { reportDialogTransaction } from '../Shared/dialogTransactionFlow';
  import { createResetGate } from '../Shared/resetGate';
  import { ClaimAction } from '../Shared/types';
  import { DialogStep, DialogStepper } from '../Stepper';
  import ClaimStepNavigation from './ClaimStepNavigation.svelte';
  import { isMessageNotReceivedError } from './error';
  import { type ClaimDialogMode, shouldSkipMessageStatusCheck } from './mode';
  import { claimWithQuotaGuard, showQuotaToastForClaimError } from './quota';
  import { ClaimSteps, INITIAL_STEP } from './types';

  const log = getLogger('ClaimDialog');

  const dialogId = `dialog-${crypto.randomUUID()}`;
  const dispatch = createEventDispatcher();

  export let dialogOpen = false;

  export let loading = false;

  export let nft: NFT | null = null;

  export let activeStep: ClaimSteps = INITIAL_STEP;

  export let bridgeTx: BridgeTransaction;
  export let directClaim = false;

  export const handleClaimClick = async () => {
    await claimWithQuotaGuard({
      bridgeTx,
      claim: () => ClaimComponent.claim(ClaimAction.CLAIM, force, shouldSkipMessageStatusCheck(claimMode)),
      setClaiming: (value) => (claiming = value),
      showQuotaReachedToast,
      onQuotaCheckError: logQuotaCheckError,
    });
    // The attempt settled without a transaction - the quota refused it, or the error handler
    // has already reported it - unless one is pending now, which the gate leaves alone
    resetGate.settle();
  };

  let force = false;
  // let canForceTransaction = false;
  let canContinue = false;
  let claiming: boolean;
  /**
   * A claim transaction is on chain and its outcome is not known yet. With `claiming` this
   * is what holds the reset gate below closed, so reopening the dialog cannot offer a second
   * claim for a message whose first claim may still confirm.
   */
  let claimTxPending = false;
  let claimingDone = false;
  let ClaimComponent: Claim;
  let txHash: Hash;
  let hideContinueButton: boolean;
  let isDesktopOrLarger = false;
  let claimMode: ClaimDialogMode = directClaim ? 'try_claim' : 'claim';

  const handleAccountChange = () => {
    reset();
  };

  const closeDialog = () => {
    dialogOpen = false;
    reset();
  };

  const handleClaimTxSent = async (event: CustomEvent<{ txHash: Hash; action: ClaimAction }>) => {
    const { txHash: transactionHash, action } = event.detail;
    txHash = transactionHash;
    log('handle claim tx sent', txHash, action);
    claiming = true;
    claimTxPending = true;

    const outcome = await reportDialogTransaction({
      txHash,
      chainId: Number(bridgeTx.destChainId),
      t: $t,
      failureTitleKey: 'bridge.errors.process_message_error',
    });

    // A wait that gave up leaves the transaction live and may yet claim the message. Lowering
    // the flags would re-enable Claim for it, so the dialog stays exactly as it is
    if (outcome === 'pending') return;

    claiming = false;
    claimTxPending = false;
    if (outcome !== 'failed') {
      claimingDone = true;
      dispatch('claimingDone');
    }
    // A close refused while the transaction was pending is applied now
    resetGate.settle();
  };

  const showQuotaReachedToast = () => {
    errorToast({
      title: $t('bridge.errors.claim.quota_reached.title'),
      message: $t('bridge.errors.claim.quota_reached.message'),
    });
  };

  const showUnknownErrorToast = () => {
    errorToast({
      title: $t('bridge.errors.unknown_error.title'),
      message: $t('bridge.errors.unknown_error.message'),
    });
  };

  const logQuotaCheckError = (quotaError: unknown) => {
    console.error('Failed to check claim quota', quotaError);
  };

  const handleClaimError = async (event: CustomEvent<{ error: unknown; action: ClaimAction }>) => {
    //TODO: update this to display info alongside toasts
    const err = event.detail.error;
    // canForceTransaction = true;
    switch (true) {
      case err instanceof NotConnectedError:
        warningToast({ title: $t('messages.account.required') });
        break;
      case err instanceof UserRejectedRequestError:
        warningToast({ title: $t('transactions.actions.claim.rejected.title') });
        break;
      case err instanceof InsufficientBalanceError:
        dispatch('insufficientFunds', { tx: bridgeTx });
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
      case err instanceof ContractFunctionExecutionError:
        console.error(err);
        if (isMessageNotReceivedError(err)) {
          errorToast({
            title: $t('bridge.errors.claim.not_received.title'),
            message: $t('bridge.errors.claim.not_received.message'),
          });
        } else {
          if (
            !(await showQuotaToastForClaimError(err, bridgeTx, {
              showQuotaReachedToast,
              onQuotaCheckError: logQuotaCheckError,
            }))
          ) {
            showUnknownErrorToast();
          }
        }
        break;
      default:
        console.error(err);
        showUnknownErrorToast();
        break;
    }
    claiming = false;
    resetGate.settle();
  };

  /**
   * Closing the dialog or switching accounts cancels neither a claim awaiting the wallet's
   * signature nor one already on chain. Rewinding the steps here - and clearing `claiming`,
   * as this used to - handed the user a fresh Claim button for that same message as soon as
   * the dialog was reopened from the row, while the first request was still in the wallet.
   * The gate refuses the rewind while the claim is in flight and applies it once the attempt
   * has settled; `claiming` itself is only ever lowered by the error and outcome handlers.
   */
  const resetGate = createResetGate({
    inFlight: () => claiming || claimTxPending,
    isOpen: () => dialogOpen,
    rewind: () => {
      activeStep = INITIAL_STEP;
      claimingDone = false;
      // canForceTransaction = false;
    },
  });

  const reset = () => {
    resetGate.request();
  };

  $: claimMode = directClaim ? 'try_claim' : 'claim';

  let previousStep: ClaimSteps;
  $: if (activeStep !== previousStep) {
    previousStep = activeStep;
  }
</script>

<dialog
  id={dialogId}
  class="modal {isDesktopOrLarger ? '' : 'modal-bottom'}"
  class:modal-open={dialogOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: dialogOpen, callback: closeDialog, uuid: dialogId }}>
  <div class="modal-box relative w-full bg-neutral-background absolute md:min-h-[600px]">
    <div class="w-full f-between-center">
      <CloseButton onClick={closeDialog} />
      <h3 class="title-body-bold">{$t('transactions.claim.steps.title')}</h3>
    </div>
    <div class="h-sep mx-[-24px] mt-[20px]" />
    <div class="w-full h-full f-col">
      <DialogStepper>
        <DialogStep
          stepIndex={ClaimSteps.CHECK}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.CHECK}>{$t('transactions.claim.steps.pre_check.title')}</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.REVIEW}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.REVIEW}>{$t('common.review')}</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.CONFIRM}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.CONFIRM}>{$t('bridge.step.confirm.title')}</DialogStep>
      </DialogStepper>
      {#if activeStep === ClaimSteps.CHECK}
        <ClaimPreCheck tx={bridgeTx} bind:canContinue bind:hideContinueButton on:closeDialog={closeDialog} />
      {:else if activeStep === ClaimSteps.REVIEW}
        <ReviewStep tx={bridgeTx} {nft} />
      {:else if activeStep === ClaimSteps.CONFIRM}
        <ClaimConfirmStep
          {bridgeTx}
          bind:txHash
          on:claim={handleClaimClick}
          bind:claiming
          bind:canClaim={canContinue}
          bind:claimingDone />
      {/if}
      <div class="f-col text-left self-end h-full w-full">
        <div class="f-col gap-4 mt-[20px]">
          <ClaimStepNavigation
            bind:activeStep
            bind:canContinue
            bind:loading
            bind:claiming
            {hideContinueButton}
            on:closeDialog={closeDialog}
            bind:claimingDone />
        </div>
      </div>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>

<Claim bind:bridgeTx bind:this={ClaimComponent} on:error={handleClaimError} on:claimingTxSent={handleClaimTxSent} />

<OnAccount change={handleAccountChange} />

<DesktopOrLarger bind:is={isDesktopOrLarger} />
