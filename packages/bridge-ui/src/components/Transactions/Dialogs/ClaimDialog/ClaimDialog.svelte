<script lang="ts">
  import { t } from 'svelte-i18n';
  import type { Hash } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { CloseButton } from '$components/Button';
  import { infoToast, successToast } from '$components/NotificationToast/NotificationToast.svelte';
  import OnAccount from '$components/OnAccount/OnAccount.svelte';
  import Claim from '$components/Transactions/Dialogs/Claim.svelte';
  import { getInvocationDelaysForDestBridge } from '$libs/bridge/getInvocationDelaysForDestBridge';
  import { getProofReceiptForMsgHash } from '$libs/bridge/getProofReceiptForMsgHash';
  import type { BridgeTransaction, GetProofReceiptResponse } from '$libs/bridge/types';
  import type { startPolling } from '$libs/polling/messageStatusPoller';
  import { noop } from '$libs/util/noop';
  import { uid } from '$libs/util/uid';
  import { connectedSourceChain } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import { DialogStep, DialogStepper } from '../Stepper';
  import ClaimStepNavigation from './ClaimStepNavigation.svelte';
  import ClaimConfirmStep from './ClaimSteps/ClaimConfirmStep.svelte';
  import ClaimPreCheck from './ClaimSteps/ClaimPreCheck.svelte';
  import ClaimReviewStep from './ClaimSteps/ClaimReviewStep.svelte';
  import { ClaimSteps, ClaimTypes } from './types';

  const dialogId = `dialog-${uid()}`;
  // const dispatch = createEventDispatcher();

  const INITIAL_STEP = ClaimSteps.CHECK;

  export let dialogOpen = false;

  export let polling: ReturnType<typeof startPolling>;

  export let delays: readonly bigint[];

  export const handleClaimClick = async () => {
    ClaimComponent.claim();
  };

  const handleAccountChange = () => {
    activeStep = INITIAL_STEP;
  };

  let canContinue = false;

  let proofReceipt: GetProofReceiptResponse;

  let claiming: boolean;
  let claimingDone = false;

  const closeDialog = () => {
    dialogOpen = false;
    reset();
  };

  let ClaimComponent: Claim;

  export let activeStep: ClaimSteps = INITIAL_STEP;

  export let item: BridgeTransaction;

  const handleClaimTxSent = async (event: CustomEvent<{ txHash: Hash; type: ClaimTypes }>) => {
    claimingDone = true;

    const { txHash, type } = event.detail;
    const explorer = chainConfig[Number(item.destChainId)]?.blockExplorers?.default.url;

    if (type === ClaimTypes.CLAIM) {
      infoToast({
        title: $t('transactions.actions.claim.tx.title'),
        message: $t('transactions.actions.claim.tx.message', {
          values: {
            token: item.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      });
      await pendingTransactions.add(txHash, Number(item.destChainId));
    } else {
      // TODO!
      infoToast({
        title: $t('transactions.actions.claim.tx.title'),
        message: $t('transactions.actions.claim.tx.message', {
          values: {
            token: item.symbol,
            url: `${explorer}/tx/${txHash}`,
          },
        }),
      });
      await pendingTransactions.add(txHash, Number(item.destChainId));
    }

    //TODO: this could be just step 1 of 2, change text accordingly
    successToast({
      title: $t('transactions.actions.claim.success.title'),
      message: $t('transactions.actions.claim.success.message', {
        values: {
          network: $connectedSourceChain.name,
        },
      }),
    });
  };

  const handleClaimError = () => noop;
  // const handleClaimError = (event: CustomEvent<{ error: unknown; type: ClaimTypes }>) => {
  //   //TODO: update this to display info alongside toasts

  // };

  const reset = () => {
    activeStep = INITIAL_STEP;
  };

  const fetchDelayInfo = async () => {
    delays = await getInvocationDelaysForDestBridge(item);
  };

  $: loading = claiming;

  $: if (dialogOpen) {
    getProofReceiptForMsgHash({
      msgHash: item.hash,
      srcChainId: item.srcChainId,
      destChainId: item.destChainId,
    }).then((receipts) => {
      proofReceipt = receipts;
    });
  }
  fetchDelayInfo();
</script>

<dialog id={dialogId} class="modal" class:modal-open={dialogOpen}>
  <div class="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute md:min-h-[500px]">
    <CloseButton onClick={closeDialog} />
    <div class="w-full h-full f-col">
      <h3 class="title-body-bold mb-7">Claim your assets</h3>
      <DialogStepper>
        <DialogStep
          stepIndex={ClaimSteps.CHECK}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.CHECK}>Prerequisites(todo)</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.REVIEW}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.REVIEW}>{$t('bridge.step.review.title')}</DialogStep>
        <DialogStep
          stepIndex={ClaimSteps.CONFIRM}
          currentStepIndex={activeStep}
          isActive={activeStep === ClaimSteps.CONFIRM}>{$t('bridge.step.confirm.title')}</DialogStep>
      </DialogStepper>

      {#if activeStep === ClaimSteps.CHECK}
        <ClaimPreCheck tx={item} bind:canContinue {polling} {delays} {proofReceipt} />
      {:else if activeStep === ClaimSteps.REVIEW}
        <ClaimReviewStep tx={item} />
      {:else if activeStep === ClaimSteps.CONFIRM}
        <ClaimConfirmStep on:claim={handleClaimClick} bind:claiming bind:canClaim={canContinue} bind:claimingDone />
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

<Claim
  bind:bridgeTx={item}
  bind:this={ClaimComponent}
  on:error={handleClaimError}
  bind:claiming
  on:claimingTxSent={handleClaimTxSent} />

<OnAccount change={handleAccountChange} />
