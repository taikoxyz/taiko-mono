<script lang="ts">
  import { importDone } from '$components/Bridge/state';
  import { ChainSelector, ChainSelectorType } from '$components/ChainSelectors';

  import TokenInput from './TokenInput/TokenInput.svelte';

  let validInput = false;

  export let hasEnoughEth: boolean = false;

  $: $importDone = validInput;
</script>

<ChainSelector type={ChainSelectorType.COMBINED} />

<TokenInput bind:validInput bind:hasEnoughEth />
