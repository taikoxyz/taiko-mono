<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { ContractFunctionExecutionError, type Hash, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { CloseButton } from '$components/Button';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { errorToast, successToast, warningToast } from '$components/NotificationToast';
  import { infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import type { BridgeTransaction } from '$libs/bridge';
  import {
    InsufficientBalanceError,
    InvalidProofError,
    NotConnectedError,
    ProcessMessageError,
    RetryError,
  } from '$libs/error';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { connectedSourceChain } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Claim from '../Claim.svelte';
  import { ClaimConfirmStep, ReviewStep } from '../Shared';
  import { ClaimAction } from '../Shared/types';
  import { DialogStep, DialogStepper } from '../Stepper';
  import ReleaseStepNavigation from './ReleaseStepNavigation.svelte';
  import ReleasePreCheck from './ReleaseSteps/ReleasePreCheck.svelte';
  import { INITIAL_STEP, ReleaseSteps } from './types';

  const log = getLogger('ReleaseDialog');

  const dialogId = `dialog-${uid()}`;
  const dispatch = createEventDispatcher();

  export let bridgeTx: BridgeTransaction;

  export let dialogOpen = false;

  let canContinue = false;
  let activeStep: ReleaseSteps = INITIAL_STEP;
  let txHash: Hash;
  let releasing: boolean;
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
    releasing = false;
    activeStep = INITIAL_STEP;
  };

  const handleClaimTxSent = async (event: CustomEvent<{ txHash: Hash; action: ClaimAction }>) => {
    const { txHash: transactionHash, action } = event.detail;
    txHash = transactionHash;
    log('handle claim tx sent', txHash, action);
    releasing = true;

    const explorer = chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;

    infoToast({
      title: $t('transactions.actions.claim.tx.title'),
      message: $t('transactions.actions.claim.tx.message', {
        values: {
          token: bridgeTx.symbol,
          url: `${explorer}/tx/${txHash}`,
        },
      }),
    });
    await pendingTransactions.add(txHash, Number(bridgeTx.destChainId));

    releasingDone = true;

    dispatch('claimingDone');

    successToast({
      title: $t('transactions.actions.claim.success.title'),
      message: $t('transactions.actions.claim.success.message', {
        values: {
          network: $connectedSourceChain.name,
        },
      }),
    });
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
      case err instanceof ContractFunctionExecutionError:
        console.error(err);
        if (err.message.includes('B_NOT_RECEIVED')) {
          errorToast({
            title: $t('bridge.errors.claim.not_received.title'),
            message: $t('bridge.errors.claim.not_received.message'),
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
    releasing = true;
    await ClaimComponent.claim(ClaimAction.RELEASE);
    releasing = false;
  };

  $: releasing = false;

  $: loading = releasing;
</script>

<dialog id={dialogId} class="modal {isDesktopOrLarger ? '' : 'modal-bottom'}" class:modal-open={dialogOpen}>
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
