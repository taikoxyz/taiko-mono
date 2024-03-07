<script lang="ts">
  import { onMount } from 'svelte';

  import { importDone, processingFeeMethod, recipientAddress } from '$components/Bridge/state';
  import { ChainSelector, ChainSelectorType } from '$components/ChainSelectors';
  import { ProcessingFeeMethod } from '$libs/fee';

  import TokenInput from './TokenInput/TokenInput.svelte';

  let validInput = false;

  export let hasEnoughEth: boolean = false;

  const reset = () => {
    $recipientAddress = null;
    $processingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  };

  onMount(async () => {
    reset();
  });

  $: $importDone = validInput;
</script>

<ChainSelector type={ChainSelectorType.COMBINED} />

<TokenInput bind:validInput bind:hasEnoughEth />
