<script lang="ts">
  import { createEventDispatcher, onMount } from 'svelte';
  import { zeroAddress } from 'viem';

  import ActionButton from '$components/Button/ActionButton.svelte';
  import type { BridgeTransaction, GetProofReceiptResponse } from '$libs/bridge';
  import { getInvocationDelayForTx } from '$libs/bridge/getInvocationDelayForTx';
  import { getProofReceiptForMsgHash } from '$libs/bridge/getProofReceiptForMsgHash';
  import { PollingEvent, type startPolling } from '$libs/polling/messageStatusPoller';

  export let tx: BridgeTransaction;

  export let delays: readonly bigint[];

  export let canClaim = false;

  export let polling: ReturnType<typeof startPolling>;

  const dispatch = createEventDispatcher();

  const handleClaimClick = async () => {
    dispatch('claim');
  };

  $: preferredDelay = 0n;

  const convertSecondsToTime = (seconds: bigint): string => {
    if (seconds <= 0n) {
      canClaim = true;
      return 'You can claim now';
    }

    const minutes = seconds / 60n;
    const hours = minutes / 60n;
    const remainingMinutes = minutes % 60n;

    if (hours > 0n) {
      const hoursPart = hours === 1n ? '1 hour' : `${hours} hours`;
      const minutesPart = remainingMinutes > 0n ? `, ${remainingMinutes} min` : '';
      return `${hoursPart}${minutesPart} until you can claim`;
    } else if (minutes > 0n) {
      return minutes === 1n ? '1 minute until you can claim' : `${minutes} minutes until you can claim`;
    } else {
      return 'less than a minute until you can claim';
    }
  };

  $: remaining = delays && preferredDelay - delays[0] > 0n ? preferredDelay - delays[0] : 0n;

  const onDelayChange = (remainingDelayInSeconds: bigint[]) => {
    preferredDelay = remainingDelayInSeconds[0];
  };

  let proofReceipt: GetProofReceiptResponse;
  onMount(async () => {
    if (polling?.emitter) {
      proofReceipt = await getProofReceiptForMsgHash({
        msgHash: tx.hash,
        srcChainId: tx.srcChainId,
        destChainId: tx.destChainId,
      });

      // The following listeners will trigger change in the UI
      polling.emitter.on(PollingEvent.DELAY, onDelayChange);
    }
    convertSecondsToTime(preferredDelay);
  });
</script>

<h1>Confirm! TODO</h1>
<div class="space-y-[18px]">
  {#if proofReceipt && proofReceipt[1] !== zeroAddress}
    {delays[0]} vs {preferredDelay} vs {remaining}

    <progress class="progress progress-primary w-full" value={Number(delays[0] - remaining)} max={Number(remaining)}
    ></progress>
  {/if}

  <ActionButton onPopup priority="primary" on:click={() => handleClaimClick()} disabled={!canClaim}
    >Claim now</ActionButton>
  <!-- <button class="btn" on:click={() => handleClaimClick()}>Test claim</button> -->
  <button class="btn" on:click={() => getInvocationDelayForTx(tx)}>Get delays</button>
</div>
