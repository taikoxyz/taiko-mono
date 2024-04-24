<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { ContractFunctionExecutionError, type Hash, UserRejectedRequestError } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { CloseButton } from '$components/Button';
  import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
  import Claim from '$components/Dialogs/Claim.svelte';
  import {
    errorToast,
    infoToast,
    successToast,
    warningToast,
  } from '$components/NotificationToast/NotificationToast.svelte';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import type { BridgeTransaction } from '$libs/bridge/types';
  import {
    InsufficientBalanceError,
    InvalidProofError,
    NotConnectedError,
    ProcessMessageError,
    RetryError,
  } from '$libs/error';
  import type { NFT } from '$libs/token';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { connectedSourceChain } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import { ClaimConfirmStep, ReviewStep } from '../Shared';
  import { ClaimAction } from '../Shared/types';
  import { DialogStep, DialogStepper } from '../Stepper';
  import ClaimStepNavigation from './ClaimStepNavigation.svelte';
  import ClaimPreCheck from './ClaimSteps/ClaimPreCheck.svelte';
  import { ClaimSteps, INITIAL_STEP } from './types';

  const log = getLogger('ClaimDialog');

  const dialogId = `dialog-${uid()}`;
  const dispatch = createEventDispatcher();

  export let dialogOpen = false;

  export let loading = false;

  export let nft: NFT | null = null;

  export let activeStep: ClaimSteps = INITIAL_STEP;

  export let bridgeTx: BridgeTransaction;

  export const handleClaimClick = async () => {
    claiming = true;
    await ClaimComponent.claim(ClaimAction.CLAIM);
  };

  let canContinue = false;
  let claiming: boolean;
  let claimingDone = false;
  let ClaimComponent: Claim;
  let txHash: Hash;
  let hideContinueButton: boolean;
  let isDesktopOrLarger = false;

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

    const explorer = chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;

    if (action === ClaimAction.CLAIM) {
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
    } else {
      // Retry
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
    }

    claimingDone = true;

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

  const handleClaimError = (event: CustomEvent<{ error: unknown; action: ClaimAction }>) => {
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
    claiming = false;
  };

  const reset = () => {
    activeStep = INITIAL_STEP;
    claimingDone = false;
  };

  let checkingPrerequisites: boolean;

  let previousStep: ClaimSteps;
  $: if (activeStep !== previousStep) {
    previousStep = activeStep;
  }
</script>

<dialog id={dialogId} class="modal {isDesktopOrLarger ? '' : 'modal-bottom'}" class:modal-open={dialogOpen}>
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
        <ClaimPreCheck tx={bridgeTx} bind:canContinue {checkingPrerequisites} bind:hideContinueButton />
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
