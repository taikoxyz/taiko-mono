<!--
  Stands in for ClaimPreCheck, which reads balances and chain state. It reports the check as
  passed on mount so a dialog under test can reach its confirm step.
-->
<script lang="ts">
  import { onMount } from 'svelte';

  import type { BridgeTransaction } from '$libs/bridge';

  export let tx: BridgeTransaction | undefined = undefined;
  export let canContinue = false;
  export let hideContinueButton = false;

  onMount(() => {
    canContinue = true;
    hideContinueButton = false;
  });
</script>

<span data-testid="pre-check" data-msg-hash={tx?.msgHash} />
