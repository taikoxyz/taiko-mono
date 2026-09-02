<!--
  Stands in for the Claim component in dialog tests. The wallet round trip is scripted by the
  test through `claimControl`: `claim` waits on whatever the test handed it and then reports
  the outcome through the same events the real component dispatches.
-->
<script lang="ts" context="module">
  import type { Hash } from 'viem';

  export type ScriptedOutcome = { txHash: Hash } | { error: unknown };

  export const claimControl: { next: Promise<ScriptedOutcome> | undefined } = { next: undefined };
</script>

<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  import type { BridgeTransaction } from '$libs/bridge';

  const dispatch = createEventDispatcher();

  export let bridgeTx: BridgeTransaction | undefined = undefined;

  export const claim = async (action: unknown) => {
    const outcome = await claimControl.next;
    if (!outcome) return;
    if ('txHash' in outcome) {
      dispatch('claimingTxSent', { txHash: outcome.txHash, action });
    } else {
      dispatch('error', { error: outcome.error, action });
    }
  };
</script>

<span data-testid="claim-stub" data-msg-hash={bridgeTx?.msgHash} />
