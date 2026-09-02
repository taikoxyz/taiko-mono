<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { ContractFunctionExecutionError, type Hash, UserRejectedRequestError } from 'viem';

  import { CloseButton } from '$components/Button';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { errorToast, warningToast } from '$components/NotificationToast';
  import { OnAccount } from '$components/OnAccount';
  import type { BridgeTransaction } from '$libs/bridge';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import {
    BlockNotSyncedError,
    InsufficientBalanceError,
    InvalidProofError,
    NotConnectedError,
    ProcessMessageError,
    ProofGenerationError,
    RetryError,
  } from '$libs/error';
  import { getLogger } from '$libs/util/logger';

  import Claim from '../Claim.svelte';
  import { isMessageNotReceivedError } from '../ClaimDialog/error';
  import { ClaimConfirmStep, ReviewStep } from '../Shared';
  import { reportDialogTransaction } from '../Shared/dialogTransactionFlow';
  import { ClaimAction } from '../Shared/types';
  import { DialogStep, DialogStepper } from '../Stepper';
  import ReleaseStepNavigation from './ReleaseStepNavigation.svelte';
  import ReleasePreCheck from './ReleaseSteps/ReleasePreCheck.svelte';
  import { INITIAL_STEP, ReleaseSteps } from './types';

  const log = getLogger('ReleaseDialog');

  const dialogId = `dialog-${crypto.randomUUID()}`;
  const dispatch = createEventDispatcher();

  export let bridgeTx: BridgeTransaction;

  export let dialogOpen = false;

  let canContinue = false;
  let activeStep: ReleaseSteps = INITIAL_STEP;
  let txHash: Hash;
  let releasing = false;
  /**
   * A release transaction is on chain and its outcome is not known yet. Distinct from
   * `releasing`, which `reset` clears: this survives a close so reopening the dialog cannot
   * offer a second release for a message whose first release may still confirm.
   */
  let releaseTxPending = false;
  let releasingDone = false;
  let ClaimComponent: Claim;
  let hideContinueButton: boolean;
  let isDesktopOrLarger = false;

  const closeDialog = () => {
    dialogOpen = false;
    reset();
  };

  const handleAccountChange = () => {
    reset();
  };

  const reset = () => {
    // Closing the dialog or switching accounts does not cancel a release already on chain.
    // Rewinding the steps and clearing `releasing` here would hand the user a fresh Release
    // button for that same message, so a still-pending transaction keeps the dialog as is.
    if (releaseTxPending) return;
    releasing = false;
    releasingDone = false;
    activeStep = INITIAL_STEP;
  };

  const handleClaimTxSent = async (event: CustomEvent<{ txHash: Hash; action: ClaimAction }>) => {
    const { txHash: transactionHash, action } = event.detail;
    txHash = transactionHash;
    log('handle release tx sent', txHash, action);
    releasing = true;
    releaseTxPending = true;

    const outcome = await reportDialogTransaction({
      // recallMessage executes on the source chain, so both the receipt wait and the
      // explorer link belong there rather than on the destination
      txHash,
      chainId: Number(bridgeTx.srcChainId),
      t: $t,
      failureTitleKey: 'bridge.errors.process_message_error',
    });

    // A wait that gave up leaves the transaction live and may yet release the funds. Lowering
    // the flags would re-enable Release for it, so the dialog stays as it is
    if (outcome === 'pending') return;

    releasing = false;
    releaseTxPending = false;
    if (outcome === 'failed') return;

    releasingDone = true;
    dispatch('claimingDone');
  };

  const handleClaimError = (event: CustomEvent<{ error: unknown; type: ClaimAction }>) => {
    //TODO: update this to display info alongside toasts
    const err = event.detail.error;
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
      // With the block-number gate gone, these two are what a release hits while the FAILED
      // signal has not reached the source chain yet: the prover refuses an empty storage slot,
      // or cannot find a synced block at all. Both used to read "Unknown error", which a user
      // reasonably took to mean the funds were gone rather than "not yet".
      case err instanceof BlockNotSyncedError:
      case err instanceof ProofGenerationError:
        console.error(err);
        warningToast({
          title: $t('bridge.errors.release.not_synced.title'),
          message: $t('bridge.errors.release.not_synced.message'),
        });
        break;
      case err instanceof ContractFunctionExecutionError:
        console.error(err);
        // The bridge reverts with B_SIGNAL_NOT_RECEIVED; the old check looked for a name the
        // contract never emits, so this branch could not be reached
        if (isMessageNotReceivedError(err)) {
          warningToast({
            title: $t('bridge.errors.release.not_received.title'),
            message: $t('bridge.errors.release.not_received.message'),
          });
        } else {
          errorToast({
            title: $t('bridge.errors.unknown_error.title'),
            message: $t('bridge.errors.unknown_error.message'),
          });
        }
        break;
      default:
        console.error(err);
        errorToast({
          title: $t('bridge.errors.unknown_error.title'),
          message: $t('bridge.errors.unknown_error.message'),
        });
        break;
    }
    releasing = false;
  };

  const handleReleaseClick = async () => {
    // claim() reports its outcome through the claimingTxSent/error events, which own the
    // `releasing` flag; clearing it here would re-enable the button while the release
    // transaction is still pending. A throw escaping claim() bypasses those events, so
    // the flag is cleared here in that case only.
    releasing = true;
    try {
      await ClaimComponent.claim(ClaimAction.RELEASE);
    } catch (error) {
      console.error('Release failed before a transaction was sent', error);
      releasing = false;
      errorToast({ title: $t('bridge.errors.unknown_error.title') });
    }
  };

  $: loading = releasing;
</script>

<dialog
  id={dialogId}
  class="modal {isDesktopOrLarger ? '' : 'modal-bottom'}"
  class:modal-open={dialogOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: dialogOpen, callback: closeDialog, uuid: dialogId }}>
  <div class="modal-box relative w-full bg-neutral-background absolute">
    <div class="w-full f-between-center">
      <CloseButton onClick={closeDialog} />
      <h3 class="title-body-bold">{$t('transactions.release.title')}</h3>
    </div>
    <div class="h-sep mx-[-24px] mt-[20px]" />
    <div class="w-full h-full f-col">
      <DialogStepper>
        <DialogStep
          stepIndex={ReleaseSteps.CHECK}
          currentStepIndex={activeStep}
          isActive={activeStep === ReleaseSteps.CHECK}>{$t('transactions.claim.steps.pre_check.title')}</DialogStep>
        <DialogStep
          stepIndex={ReleaseSteps.REVIEW}
          currentStepIndex={activeStep}
          isActive={activeStep === ReleaseSteps.REVIEW}>{$t('common.review')}</DialogStep>
        <DialogStep
          stepIndex={ReleaseSteps.CONFIRM}
          currentStepIndex={activeStep}
          isActive={activeStep === ReleaseSteps.CONFIRM}>{$t('bridge.step.confirm.title')}</DialogStep>
      </DialogStepper>
      {#if activeStep === ReleaseSteps.CHECK}
        <ReleasePreCheck tx={bridgeTx} bind:canContinue bind:hideContinueButton />
      {:else if activeStep === ReleaseSteps.REVIEW}
        <ReviewStep tx={bridgeTx} />
      {:else if activeStep === ReleaseSteps.CONFIRM}
        <ClaimConfirmStep
          {bridgeTx}
          txChainId={Number(bridgeTx.srcChainId)}
          bind:txHash
          on:claim={handleReleaseClick}
          bind:claiming={releasing}
          bind:canClaim={canContinue}
          bind:claimingDone={releasingDone} />
      {/if}
      <div class="f-col text-left self-end h-full w-full">
        <div class="f-col gap-4 mt-[20px]">
          <ReleaseStepNavigation
            bind:activeStep
            bind:canContinue
            {hideContinueButton}
            bind:loading
            bind:releasing
            on:closeDialog={closeDialog}
            bind:releasingDone />
        </div>
      </div>
    </div>
  </div>
</dialog>

<Claim bind:bridgeTx bind:this={ClaimComponent} on:error={handleClaimError} on:claimingTxSent={handleClaimTxSent} />

<OnAccount change={handleAccountChange} />

<DesktopOrLarger bind:is={isDesktopOrLarger} />
