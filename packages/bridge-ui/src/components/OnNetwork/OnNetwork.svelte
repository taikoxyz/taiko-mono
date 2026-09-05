<script lang="ts">
  import { onDestroy } from 'svelte';
  import type { Chain } from 'viem';

  import { noop } from '$libs/util/noop';
  import { connectedSourceChain } from '$stores/network';

  export let change: (newNetwork: Chain, oldNetwork: Chain) => void = noop;

  let prevNetwork = $connectedSourceChain;

  // Manual subscriptions are not auto-released like $-syntax ones: without the
  // onDestroy below, every mount leaks a handler that keeps firing forever
  const unsubscribe = connectedSourceChain.subscribe((newNetwork) => {
    // only update if the network has actually changed
    if (newNetwork?.id === prevNetwork?.id) return;
    change(newNetwork, prevNetwork);
    prevNetwork = newNetwork;
  });

  onDestroy(unsubscribe);
</script>
