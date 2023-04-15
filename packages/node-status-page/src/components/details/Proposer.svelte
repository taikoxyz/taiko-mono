<script lang="ts">
  import type { ethers } from "ethers";

  export let l1Provider: ethers.providers.JsonRpcProvider;
  export let l1TaikoAddress: string;
  export let l2Provider: ethers.providers.JsonRpcProvider;
  export let proposerAddress: string;
</script>

<div class="text-center">
  <h1 class="text-2xl">Proposer Details</h1>
</div>
