<script lang="ts">
  import { EVENT_INDEXER_API_URL } from '../../constants/envVars';
  import getCurrentProvers from '../../utils/getCurrentProvers';
  import { onMount } from 'svelte';
  import type { Prover } from '../../domain/prover';
  import { ethers } from 'ethers';
  import { truncateString } from '../../utils/truncateString';
  let provers: Prover[] = [];

  onMount(async () => {
    provers = await getCurrentProvers(EVENT_INDEXER_API_URL);
  });
</script>

<div class="my-4 md:px-4">
  <th>Address</th>
  <th>Amount</th>
  <th>Capacity</th>
  {#each provers as prover}
    <tr>
      <td>{truncateString(prover.address, 8)}...</td>
      <td>{ethers.utils.formatUnits(prover.amountStaked.toString(), 8)}</td>
      <td>{prover.currentCapacity}</td>
    </tr>
  {/each}
</div>
