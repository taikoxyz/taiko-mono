<script lang="ts">
  import { getBalance, switchChain } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { type Address, parseEther, zeroAddress } from 'viem';

  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { claimConfig } from '$config';
  import type { BridgeTransaction, GetProofReceiptResponse } from '$libs/bridge';
  import { getInvocationDelayForTx } from '$libs/bridge/getInvocationDelayForTx';
  import { getChainName } from '$libs/chain';
  import { PollingEvent, type startPolling } from '$libs/polling/messageStatusPoller';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';

  export let tx: BridgeTransaction;
  export let polling: ReturnType<typeof startPolling>;
  export let canContinue = false;

  export let bridgeDelays: readonly bigint[];
  export let proofReceipt: GetProofReceiptResponse;

  let proofReceiptAddress: Address;

  const switchChains = async () => {
    $switchingNetwork = true;
    try {
      await switchChain(config, { chainId: Number(tx.destChainId) });
    } catch (err) {
      console.error(err);
    } finally {
      $switchingNetwork = false;
    }
  };

  export let checkingPrerequisites: boolean;

  const checkEnoughBalance = async (address: Maybe<Address>, chainId: number) => {
    if (!address) {
      return false;
    }
    checkingPrerequisites = true;

    const balance = await getBalance(config, { address, chainId });

    if (balance.value < parseEther(String(claimConfig.minimumEthToClaim))) {
      hasEnoughEth = false;
      checkingPrerequisites = false;
    }
    hasEnoughEth = true;
    checkingPrerequisites = false;
  };

  const convertSecondsToTime = (sec: number): { hours: number; minutes: number; seconds: number } => {
    let totalSeconds = Number(sec);
    const hours = Math.floor(totalSeconds / 3600);
    totalSeconds -= hours * 3600;
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;

    return { hours, minutes, seconds };
  };

  const formatTimeToString = ({
    hours,
    minutes,
    seconds,
  }: {
    hours: number;
    minutes: number;
    seconds: number;
  }): string => {
    if (hours < 0 || minutes < 0 || seconds < 0) {
      return $t('transactions.claim.steps.pre_check.no_delay');
    }

    if (hours > 0) {
      // If hours are present, include hours and minutes in the output
      return `~${hours}h ${minutes.toString().padStart(2, '0')}min`;
    } else if (minutes > 0) {
      // If no hours but minutes are present, include only minutes
      return `~${minutes}min`;
    } else if (seconds > 0) {
      // If less than a minute, show seconds
      return `~${seconds}sec`;
    }
    // If none of the above, it means no delay
    return $t('transactions.claim.steps.pre_check.no_delay');
  };

  const onDelayChange = ({ remainingDelayInSeconds }: { remainingDelayInSeconds: bigint }) => {
    if (remainingDelayInSeconds >= 0n) {
      preferredDelayInSeconds = Number(remainingDelayInSeconds);
    } else {
      preferredDelayInSeconds = 0;
    }
  };

  const checkTxDelay = async () => {
    const invocationDelaysForTx = await getInvocationDelayForTx(tx);
    preferredDelayInSeconds = Number(invocationDelaysForTx.preferredDelay);
  };

  const checkConditions = async () => {
    await checkEnoughBalance($account.address, Number(tx.destChainId));
    if (bridgeDelays && bridgeDelays[0] > 0n) {
      await checkTxDelay();
    }
  };

  $: if (proofReceipt) {
    proofReceiptAddress = proofReceipt[1];
  }

  $: txDestChainName = getChainName(Number(tx.destChainId));

  $: correctChain = Number(tx.destChainId) === $connectedSourceChain.id;

  $: if (correctChain && !checkingPrerequisites && hasEnoughEth && $account && preferredDelayInSeconds <= 0) {
    canContinue = true;
  } else {
    canContinue = false;
  }

  $: $account && tx.destChainId, checkConditions();

  $: {
    if (polling?.emitter) {
      // The following listeners will trigger change in the UI
      polling.emitter.on(PollingEvent.DELAY, onDelayChange);
    }
    remainingDelayString = formatTimeToString(convertSecondsToTime(Number(preferredDelayInSeconds)));
  }
  $: remainingDelayString = '';
  $: invocationDelayString = bridgeDelays && formatTimeToString(convertSecondsToTime(Number(bridgeDelays[0])));
  $: preferredDelayInSeconds = 0;
  $: hasEnoughEth = false;

  $: twoStepBridge = bridgeDelays && bridgeDelays[0] > 0n ? true : false;

  $: claimStep = proofReceiptAddress && proofReceiptAddress !== zeroAddress ? '2/2' : '1/2';
</script>

<div class="space-y-[25px] mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">{$t('transactions.claim.steps.pre_check.title')}</div>
  </div>
  <div class="min-h-[150px] grid content-between">
    <div>
      <!-- Two step claim process -->
      {#if twoStepBridge}
        <div class="h-sep" />
        <span class="text-secondary-content">
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          {@html $t('transactions.claim.steps.pre_check.two_step_claim.description', {
            values: { delay: invocationDelayString },
          })}
        </span>
        <div class="f-between-center mt-[20px]">
          <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.step')}</span>
          {#if checkingPrerequisites}
            <Spinner />
          {:else}
            <span>{claimStep}</span>
          {/if}
        </div>
        {#if proofReceiptAddress && proofReceiptAddress !== zeroAddress}
          <div class="f-between-center">
            <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.remaining_delay')}</span>
            {#if checkingPrerequisites}
              <Spinner />
            {:else}
              {remainingDelayString}
            {/if}
          </div>
        {/if}
        <div class="h-sep" />
      {/if}
      <div class="f-between-center">
        <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.chain_check')}</span>
        {#if checkingPrerequisites}
          <Spinner />
        {:else if correctChain}
          <Icon type="check-circle" fillClass="fill-positive-sentiment" />
        {:else}
          <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
        {/if}
      </div>
      <div class="f-between-center">
        <span class="text-secondary-content">{$t('transactions.claim.steps.pre_check.funds_check')}</span>
        {#if checkingPrerequisites}
          <Spinner />
        {:else if hasEnoughEth}
          <Icon type="check-circle" fillClass="fill-positive-sentiment" />
        {:else}
          <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
        {/if}
      </div>
    </div>
  </div>
  {#if !canContinue && !correctChain}
    <div class="h-sep" />
    <div class="f-col space-y-[16px]">
      <ActionButton
        onPopup
        priority="primary"
        disabled={$switchingNetwork}
        loading={$switchingNetwork}
        on:click={() => {
          switchChains();
        }}>{$t('common.switch_to')} {txDestChainName}</ActionButton>
    </div>
  {/if}
</div>
