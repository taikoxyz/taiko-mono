<script lang="ts">
  import { getBalance, switchChain } from '@wagmi/core';
  import { type Address, parseEther, zeroAddress } from 'viem';

  import { ActionButton } from '$components/Button';
  import { Icon } from '$components/Icon';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { claimConfig } from '$config';
  import type { BridgeTransaction, GetProofReceiptResponse } from '$libs/bridge';
  import { getChainName } from '$libs/chain';
  import { InsufficientBalanceError } from '$libs/error';
  import { PollingEvent, type startPolling } from '$libs/polling/messageStatusPoller';
  import { config } from '$libs/wagmi';
  import { account } from '$stores/account';
  import { connectedSourceChain, switchingNetwork } from '$stores/network';

  export let tx: BridgeTransaction;
  export let polling: ReturnType<typeof startPolling>;
  export let canContinue = false;

  export let delays: readonly bigint[];
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
      throw new InsufficientBalanceError('user has insufficient balance');
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
    return 'No delay';
  };

  const onDelayChange = ({ remainingDelayInSeconds }: { remainingDelayInSeconds: bigint }) => {
    if (remainingDelayInSeconds >= 0n) {
      preferredDelayInSeconds = Number(remainingDelayInSeconds);
    } else {
      preferredDelayInSeconds = 0;
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

  $: $account && tx.destChainId, checkEnoughBalance($account.address, Number(tx.destChainId));

  $: {
    if (polling?.emitter) {
      // The following listeners will trigger change in the UI
      polling.emitter.on(PollingEvent.DELAY, onDelayChange);
    }
    remainingDelayString = formatTimeToString(convertSecondsToTime(Number(preferredDelayInSeconds)));
  }
  $: remainingDelayString = '';
  $: invocationDelayString = delays && formatTimeToString(convertSecondsToTime(Number(delays[0])));
  $: preferredDelayInSeconds = 0;
  $: hasEnoughEth = false;

  $: twoStepBridge = delays && delays[0] > 0n ? true : false;
</script>

<div class="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[20px]">
  <div class="flex justify-between mb-2 items-center">
    <div class="font-bold text-primary-content">Prerequisites</div>
  </div>
  <div>
    <!-- Two step claim process -->
    {#if twoStepBridge}
      <div class="h-sep" />
      <span>
        As you are claiming from L2->L1 there is additional security in the form a two step claim process. Please refer
        to our documentation for more information. You will need to claim twice with a delay of <span
          class="font-bold text-primary"
          >{invocationDelayString}
        </span>after the first claim.
      </span>
      <div class="f-between-center mt-[20px]">
        <div>Claim step</div>
        {#if checkingPrerequisites}
          <Spinner />
        {:else if proofReceiptAddress && proofReceiptAddress !== zeroAddress}
          2/2
        {:else}
          1/2
        {/if}
      </div>
      {#if proofReceiptAddress && proofReceiptAddress !== zeroAddress}
        <div class="f-between-center">
          <div>Remaining delay</div>
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
      <div>Connected to the correct chain:</div>
      {#if checkingPrerequisites}
        <Spinner />
      {:else if correctChain}
        <Icon type="check-circle" fillClass="fill-positive-sentiment" />
      {:else}
        <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
      {/if}
    </div>
    <div class="f-between-center">
      <div>Enough funds to claim</div>
      {#if checkingPrerequisites}
        <Spinner />
      {:else if hasEnoughEth}
        <Icon type="check-circle" fillClass="fill-positive-sentiment" />
      {:else}
        <Icon type="x-close-circle" fillClass="fill-negative-sentiment" />
      {/if}
    </div>
    {#if canContinue}
      <div class="h-sep" />
      You can continue with the claim process!
    {:else if !canContinue && !correctChain}
      <div class="h-sep" />
      <div class="f-col space-y-[16px]">
        <div>
          This transaction is bridging to <span class="font-bold text-primary">{txDestChainName}</span> You need to be connected
          to this chain
        </div>

        <ActionButton
          onPopup
          priority="primary"
          disabled={$switchingNetwork}
          loading={$switchingNetwork}
          on:click={() => {
            switchChains();
          }}>Switch to {txDestChainName}</ActionButton>
      </div>
    {/if}
  </div>
</div>
