<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { type Hash, UserRejectedRequestError } from 'viem';

  import { CloseButton } from '$components/Button';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { DialogStep, DialogStepper } from '$components/Dialogs/Stepper';
  import { errorToast, warningToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import type { BridgeTransaction } from '$libs/bridge';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { getLogger } from '$libs/util/logger';

  import Claim from '../Claim.svelte';
  import { claimWithQuotaGuard, showQuotaToastForClaimError } from '../ClaimDialog/quota';
  import { ClaimConfirmStep, ReviewStep } from '../Shared';
  import ClaimPreCheck from '../Shared/ClaimPreCheck.svelte';
  import { reportDialogTransaction } from '../Shared/dialogTransactionFlow';
  import { ClaimAction } from '../Shared/types';
  import RetryStepNavigation from './RetryStepNavigation.svelte';
  import RetryOptionStep from './RetrySteps/RetryOptionStep.svelte';
  import { selectedRetryMethod } from './state';
  import { INITIAL_STEP, RETRY_OPTION, RetrySteps } from './types';

  export let dialogOpen = false;

  export let bridgeTx: BridgeTransaction;

  export let loading = false;

  export let activeStep: RetrySteps = INITIAL_STEP;

  const log = getLogger('RetryDialog');
  const dispatch = createEventDispatcher();

  const dialogId = `dialog-${crypto.randomUUID()}`;

  let canContinue = false;
  let retrying: boolean;
  /**
   * A retry transaction is on chain and its outcome is not known yet. Distinct from
   * `retrying`, which `reset` clears: this survives a close so reopening the dialog cannot
   * offer a second retry for a message whose first retry may still confirm.
   */
  let retryTxPending = false;
  let retryDone = false;
  let ClaimComponent: Claim;
  let isDesktopOrLarger = false;

  let hideContinueButton = false;

  let txHash: Hash;

  const showQuotaReachedToast = () => {
    errorToast({
      title: $t('bridge.errors.claim.quota_reached.title'),
      message: $t('bridge.errors.claim.quota_reached.message'),
    });
  };

  const logQuotaCheckError = (quotaError: unknown) => {
    console.error('Failed to check claim quota', quotaError);
  };

  const handleRetryError = async (event: CustomEvent<{ error: unknown }>) => {
    const err = event.detail.error;
    if (
      !(await showQuotaToastForClaimError(err, bridgeTx, {
        showQuotaReachedToast,
        onQuotaCheckError: logQuotaCheckError,
      }))
    ) {
      console.error(err);
      // Every non-quota failure needs user-visible feedback, not just a console line
      if (err instanceof UserRejectedRequestError) {
        warningToast({ title: $t('transactions.actions.claim.rejected.title') });
      } else {
        errorToast({ title: $t('bridge.errors.retry_error') });
      }
    }
    retrying = false;
  };

  const handleAccountChange = () => {
    reset();
  };

  const reset = () => {
    // Closing the dialog or switching accounts does not cancel a retry already on chain.
    // Rewinding the steps and clearing `retrying` here would hand the user a fresh Retry
    // button for that same message, so a still-pending transaction keeps the dialog as is.
    if (retryTxPending) return;
    activeStep = INITIAL_STEP;
    $selectedRetryMethod = RETRY_OPTION.CONTINUE;
    retryDone = false;
    retrying = false;
  };

  const closeDialog = () => {
    dialogOpen = false;
    reset();
  };

  export const handleClaimClick = async () => {
    await claimWithQuotaGuard({
      bridgeTx,
      claim: () => ClaimComponent.claim(ClaimAction.RETRY),
      setClaiming: (value) => (retrying = value),
      showQuotaReachedToast,
      onQuotaCheckError: logQuotaCheckError,
    });
  };

  const handleRetryTxSent = async (event: CustomEvent<{ txHash: Hash }>) => {
    const { txHash: transactionHash } = event.detail;
    txHash = transactionHash;
    log('handle retry tx sent', txHash);
    retrying = true;
    retryTxPending = true;

    const outcome = await reportDialogTransaction({
      txHash,
      chainId: Number(bridgeTx.destChainId),
      t: $t,
      failureTitleKey: 'bridge.errors.retry_error',
    });

    // A wait that gave up leaves the transaction live and may yet process the message.
    // Lowering the flags would re-enable Retry for it, so the dialog stays as it is
    if (outcome === 'pending') return;

    retrying = false;
    retryTxPending = false;
    if (outcome === 'failed') return;

    retryDone = true;
    dispatch('retryDone');
  };
</script>

<dialog
  id={dialogId}
  class="modal {isDesktopOrLarger ? '' : 'modal-bottom'}"
  class:modal-open={dialogOpen}
  use:closeOnEscapeOrOutsideClick={{ enabled: dialogOpen, callback: closeDialog, uuid: dialogId }}>
  <div class="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute">
    <div class="w-full f-between-center">
      <CloseButton onClick={closeDialog} />
      <h3 class="title-body-bold">{$t('transactions.retry.steps.title')}</h3>
    </div>
    <div class="h-sep mx-[-24px] mt-[20px]" />

    <div class="w-full h-full f-col">
      <DialogStepper>
        <DialogStep
          stepIndex={RetrySteps.CHECK}
          currentStepIndex={activeStep}
          isActive={activeStep === RetrySteps.CHECK}>{$t('transactions.claim.steps.pre_check.title')}</DialogStep>
        <DialogStep
          stepIndex={RetrySteps.SELECT}
          currentStepIndex={activeStep}
          isActive={activeStep === RetrySteps.SELECT}>{$t('transactions.retry.steps.select.title')}</DialogStep>
        <DialogStep
          stepIndex={RetrySteps.REVIEW}
          currentStepIndex={activeStep}
          isActive={activeStep === RetrySteps.REVIEW}>{$t('common.review')}</DialogStep>
        <DialogStep
          stepIndex={RetrySteps.CONFIRM}
          currentStepIndex={activeStep}
          isActive={activeStep === RetrySteps.CONFIRM}>{$t('common.confirm')}</DialogStep>
      </DialogStepper>

      {#if activeStep === RetrySteps.CHECK}
        <ClaimPreCheck tx={bridgeTx} bind:canContinue bind:hideContinueButton on:closeDialog={closeDialog} />
      {:else if activeStep === RetrySteps.SELECT}
        <RetryOptionStep bind:canContinue />
      {:else if activeStep === RetrySteps.REVIEW}
        <ReviewStep bind:tx={bridgeTx} />
      {:else if activeStep === RetrySteps.CONFIRM}
        <ClaimConfirmStep
          {bridgeTx}
          bind:txHash
          on:claim={handleClaimClick}
          bind:claiming={retrying}
          bind:canClaim={canContinue}
          bind:claimingDone={retryDone} />
      {/if}
      <div class="f-col text-left self-end h-full w-full">
        <div class="f-col gap-4 mt-[20px]">
          <RetryStepNavigation
            bind:activeStep
            bind:canContinue
            bind:loading
            bind:retrying
            on:closeDialog={closeDialog}
            bind:retryDone />
        </div>
      </div>
    </div>
  </div>
  <button class="overlay-backdrop" data-modal-uuid={dialogId} />
</dialog>

<Claim bind:bridgeTx bind:this={ClaimComponent} on:error={handleRetryError} on:claimingTxSent={handleRetryTxSent} />

<OnAccount change={handleAccountChange} />

<DesktopOrLarger bind:is={isDesktopOrLarger} />
