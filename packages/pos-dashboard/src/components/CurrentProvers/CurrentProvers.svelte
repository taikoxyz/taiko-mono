<script lang="ts">
  import { EVENT_INDEXER_API_URL } from '../../constants/envVars';
  import getCurrentProvers from '../../utils/getCurrentProvers';
  import { onMount } from 'svelte';
  import type { Prover } from '../../domain/prover';
  import { ethers } from 'ethers';
  import { truncateString } from '../../utils/truncateString';
  let provers: Prover[] = [];

  onMount(async () => {
    const p = await getCurrentProvers(EVENT_INDEXER_API_URL);
    provers = p.sort((a, b) => (a.amountStaked < b.amountStaked ? 1 : -1));
  });
</script>

<div class="my-4 md:px-4">
  <th>Address</th>
  <th>Amount</th>
  <th>Capacity</th>
  <th>RewardPerGas</th>
  {#each provers as prover}
    <tr>
      <td
        class="cursor-pointer"
        on:click={() =>
          window.open(
            `https://explorer.test.taiko.xyz/address/${prover.address}`,
            '_blank',
          )}>{truncateString(prover.address, 8)}...</td>
      <td>{ethers.utils.formatUnits(prover.amountStaked.toString(), 8)}</td>
      <td>{prover.currentCapacity}</td>
      <td>{prover.rewardPerGas}</td>
    </tr>
  {/each}
</div>
