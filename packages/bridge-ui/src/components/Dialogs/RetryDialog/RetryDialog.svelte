<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Hash } from 'viem';

  import { chainConfig } from '$chainConfig';
  import { CloseButton } from '$components/Button';
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { DialogStep, DialogStepper } from '$components/Dialogs/Stepper';
  import { infoToast, successToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import type { BridgeTransaction } from '$libs/bridge';
  import { closeOnEscapeOrOutsideClick } from '$libs/customActions';
  import { getLogger } from '$libs/util/logger';
  import { uid } from '$libs/util/uid';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Claim from '../Claim.svelte';
  import { ClaimConfirmStep, ReviewStep } from '../Shared';
  import { ClaimAction } from '../Shared/types';
  import RetryStepNavigation from './RetryStepNavigation.svelte';
  import RetryOptionStep from './RetrySteps/RetryOptionStep.svelte';
  import { selectedRetryMethod } from './state';
  import { INITIAL_STEP, RETRY_OPTION, RetrySteps } from './types';

  export let dialogOpen = false;

  export let bridgeTx: BridgeTransaction;

  export let loading = false;

  const log = getLogger('RetryDialog');
  const dispatch = createEventDispatcher();

  const dialogId = `dialog-${uid()}`;

  export let activeStep: RetrySteps = RetrySteps.SELECT;

  let canContinue = false;
  let retrying: boolean;
  let retryDone = false;
  let ClaimComponent: Claim;
  let isDesktopOrLarger = false;

  let txHash: Hash;

  const handleRetryError = () => {
    retrying = false;
  };

  const handleAccountChange = () => {
    reset();
  };

  const reset = () => {
    activeStep = INITIAL_STEP;
    $selectedRetryMethod = RETRY_OPTION.CONTINUE;
    retryDone = false;
  };

  const closeDialog = () => {
    dialogOpen = false;
    reset();
  };

  export const handleClaimClick = async () => {
    retrying = true;
    await ClaimComponent.claim(ClaimAction.RETRY);
  };

  const handleRetryTxSent = async (event: CustomEvent<{ txHash: Hash }>) => {
    const { txHash: transactionHash } = event.detail;
    txHash = transactionHash;
    log('handle claim tx sent', txHash);
    retrying = true;

    const explorer = chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;
    log('explorer', explorer);
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

    retryDone = true;

    dispatch('retryDone');

    successToast({
      title: $t('transactions.actions.claim.success.title'),
      message: $t('transactions.actions.claim.tx.message', {
        values: {
          url: `${explorer}/tx/${txHash}`,
        },
      }),
    });
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

      {#if activeStep === RetrySteps.SELECT}
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
