<script lang="ts">
  import { onMount } from 'svelte';

  import {
    destOwnerAddress,
    gasLimitZero,
    importDone,
    processingFeeMethod,
    recipientAddress,
  } from '$components/Bridge/state';
  import { ChainSelector, ChainSelectorType } from '$components/ChainSelectors';
  import { ProcessingFeeMethod } from '$libs/fee';

  import TokenInput from './TokenInput/TokenInput.svelte';

  let validInput = false;

  export let hasEnoughEth: boolean = false;

  const reset = () => {
    $recipientAddress = null;
    $destOwnerAddress = null;
    $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
    // Reset through the store, the way NFTBridge.resetForm does. The only other clear lives
    // in ProcessingFee.resetProcessingFee, reachable solely through RecipientStep.reset,
    // which nothing calls - so a zero gas limit chosen for one transfer stayed set for the
    // session. The drift guard then pulled the fee back to 0 behind a form that looked
    // freshly reset, and Bridge.ts reads the store at send time: the next transfer went out
    // with gasLimit 0 and no fee, processable only by its destination owner.
    $gasLimitZero = false;
  };

  onMount(async () => {
    reset();
  });

  $: $importDone = validInput;
</script>

<ChainSelector type={ChainSelectorType.COMBINED} />

<TokenInput bind:validInput bind:hasEnoughEth />
