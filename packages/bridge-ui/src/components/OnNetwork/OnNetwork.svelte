<script lang="ts">
  import type { Chain } from 'viem';

  import { noop } from '$libs/util/noop';
  import { connectedSourceChain } from '$stores/network';

  export let change: (newNetwork: Chain, oldNetwork: Chain) => void = noop;

  let prevNetwork = $connectedSourceChain;

  connectedSourceChain.subscribe((newNetwork) => {
    // only update if the network has actually changed
    if (newNetwork?.id === prevNetwork?.id) return;
    change(newNetwork, prevNetwork);
    prevNetwork = newNetwork;
  });
</script>
