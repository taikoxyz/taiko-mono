<script lang="ts">
  import { importDone } from '$components/Bridge/state';
  import CombinedChainSelector from '$components/ChainSelectors/CombinedChainSelector.svelte';

  import TokenInput from './TokenInput/TokenInput.svelte';

  let validInput = false;

  $: $importDone = validInput;
</script>

<CombinedChainSelector />
<TokenInput bind:validInput />
