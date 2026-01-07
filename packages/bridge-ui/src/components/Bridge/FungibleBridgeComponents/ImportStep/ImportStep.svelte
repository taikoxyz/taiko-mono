<script lang="ts">
  import { importDone } from '$components/Bridge/state';
  import { ChainSelector, ChainSelectorType } from '$components/ChainSelectors';

  import TokenInput from './TokenInput/TokenInput.svelte';

  let validInput = false;

  export let hasEnoughEth: boolean = false;
  export let exceedsQuota: boolean = false;

  // Note: State reset removed from onMount to preserve state when navigating back
  // from Review step. State is managed at the page level when starting a new transaction.

  $: $importDone = validInput;
</script>

<ChainSelector type={ChainSelectorType.COMBINED} />

<TokenInput bind:validInput bind:hasEnoughEth bind:exceedsQuota />
