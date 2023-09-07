<script lang="ts">
  import { noop } from '$libs/util/noop';
  import { type Network, network } from '$stores/network';

  export let change: (newNetwork: Network, oldNetwork: Network) => void = noop;

  let prevNetwork = $network;

  network.subscribe((newNetwork) => {
    // only update if the network has actually changed
    if (newNetwork?.id === prevNetwork?.id) return;
    change(newNetwork, prevNetwork);
    prevNetwork = newNetwork;
  });
</script>
