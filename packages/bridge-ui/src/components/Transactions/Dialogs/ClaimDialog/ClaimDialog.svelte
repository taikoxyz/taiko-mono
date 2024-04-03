<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import { ContractFunctionExecutionError, type Hash, UserRejectedRequestError, zeroAddress } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { CloseButton } from '$components/Button';
  import {
    errorToast,
    infoToast,
    successToast,
    warningToast,
  } from '$components/NotificationToast/NotificationToast.svelte';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import Claim from '$components/Transactions/Dialogs/Claim.svelte';
  import { getInvocationDelaysForDestBridge } from '$libs/bridge/getInvocationDelaysForDestBridge';
  import { getProofReceiptForMsgHash } from '$libs/bridge/getProofReceiptForMsgHash';
  import type { BridgeTransaction, GetProofReceiptResponse } from '$libs/bridge/types';
  import {
    InsufficientBalanceError,
    InvalidProofError,
    NotConnectedError,
    ProcessMessageError,
    RetryError,
  } from '$libs/error';
  import type { startPolling } from '$libs/polling/messageStatusPoller';
  import type { NFT } from '$libs/token';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { connectedSourceChain } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import { DialogStep, DialogStepper } from '../Stepper';
  import ClaimStepNavigation from './ClaimStepNavigation.svelte';
  import ClaimConfirmStep from './ClaimSteps/ClaimConfirmStep.svelte';
  import ClaimPreCheck from './ClaimSteps/ClaimPreCheck.svelte';
  import ClaimReviewStep from './ClaimSteps/ClaimReviewStep.svelte';
  import { ClaimSteps, ClaimTypes, INITIAL_STEP, TWO_STEP_STATE } from './types';

  const log = getLogger('ClaimDialog');

  const dialogId = `dialog-${uid()}`;
  const dispatch = createEventDispatcher();

  export let dialogOpen = false;

  export let polling: ReturnType<typeof startPolling>;

  export let delays: readonly bigint[];

  export let loading = false;

  export let nft: NFT | null = null;

  export let proofReceipt: GetProofReceiptResponse;

  export let activeStep: ClaimSteps = INITIAL_STEP;

  export let bridgeTx: BridgeTransaction;

  export const handleClaimClick = async () => {
    claiming = true;
    await ClaimComponent.claim();
  };

  let canContinue = false;
  let claiming: boolean;
  let claimingDone = false;
  let ClaimComponent: Claim;
  let txHash: Hash;

  const handleAccountChange = () => {
    activeStep = INITIAL_STEP;
  };

  const closeDialog = () => {
    dialogOpen = false;
    reset();
  };

  const handleClaimTxSent = async (event: CustomEvent<{ txHash: Hash; type: ClaimTypes }>) => {
    const { txHash: transactionHash, type } = event.detail;
    txHash = transactionHash;
    log('handle claim tx sent', txHash, type);
    claiming = true;

    const explorer = chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;

    if (type === ClaimTypes.CLAIM) {
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
      // TODO, retry, release etc.
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

    if (proveOrClaimStep === TWO_STEP_STATE.PROVE) {
      successToast({
        title: $t('transactions.actions.claim.success.title'),
        message: $t('transactions.actions.claim.success.message', {
          values: {
            network: $connectedSourceChain.name,
          },
        }),
      });
    } else if (proveOrClaimStep === TWO_STEP_STATE.CLAIM) {
      successToast({
        title: $t('transactions.actions.claim.success.title'),
        message: $t('transactions.actions.claim.success.message', {
          values: {
            network: $connectedSourceChain.name,
          },
        }),
      });
    }
  };

  const handleClaimError = (event: CustomEvent<{ error: unknown; type: ClaimTypes }>) => {
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
        if (err.message.includes('B_INVOCATION_TOO_EARLY')) {
          errorToast({
            title: $t('bridge.errors.claim.too_early.title'),
            message: $t('bridge.errors.claim.too_early.message'),
          });
        } else if (err.message.includes('B_NOT_RECEIVED')) {
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
  const fetchDelayAndReceipt = async () => {
    checkingPrerequisites = true;

    if (!proofReceipt) {
      const receipt = await getProofReceiptForMsgHash({
        msgHash: bridgeTx.msgHash,
        srcChainId: bridgeTx.srcChainId,
        destChainId: bridgeTx.destChainId,
      });

      if (receipt) {
        proofReceipt = receipt;
      }
    }

    if (!delays) {
      delays = await getInvocationDelaysForDestBridge({
        srcChainId: bridgeTx.srcChainId,
        destChainId: bridgeTx.destChainId,
      });
    }
    checkingPrerequisites = false;
  };

  let previousStep: ClaimSteps;
  $: if (activeStep !== previousStep) {
    previousStep = activeStep;
    fetchDelayAndReceipt();
  }
  $: if (dialogOpen) {
    fetchDelayAndReceipt();
  }

  $: proveOrClaimStep =
    proofReceipt && proofReceipt[1] !== zeroAddress
      ? TWO_STEP_STATE.CLAIM
      : delays && delays[0] > 0n
        ? TWO_STEP_STATE.PROVE
        : TWO_STEP_STATE.CLAIM;
</script>

<dialog id={dialogId} class="modal" class:modal-open={dialogOpen}>
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
        <ClaimPreCheck
          tx={bridgeTx}
          bind:canContinue
          bind:proofReceipt
          {polling}
          bridgeDelays={delays}
          {checkingPrerequisites} />
      {:else if activeStep === ClaimSteps.REVIEW}
        <ClaimReviewStep tx={bridgeTx} {nft} />
      {:else if activeStep === ClaimSteps.CONFIRM}
        <ClaimConfirmStep
          {bridgeTx}
          bind:txHash
          on:claim={handleClaimClick}
          bind:claiming
          bind:canClaim={canContinue}
          bind:claimingDone
          bind:proveOrClaimStep />
      {/if}
      <div class="f-col text-left self-end h-full w-full">
        <div class="f-col gap-4 mt-[20px]">
          <ClaimStepNavigation
            bind:activeStep
            bind:canContinue
            bind:loading
            bind:claiming
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
