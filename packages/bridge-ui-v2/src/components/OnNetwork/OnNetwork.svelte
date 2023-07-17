<script lang="ts">
  import { noop } from 'svelte/internal';

  import { network, type Network } from '$stores/network';

  export let change: (newNetwork: Network, oldNetwork: Network) => void = noop;

  let prevNetwork = $network;

  network.subscribe((newNetwork) => {
    change(newNetwork, prevNetwork);
    prevNetwork = newNetwork;
  });
</script>
