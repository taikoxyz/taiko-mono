<script lang="ts">
  import { onMount } from "svelte";
  import {
    fetchGuardianProversFromContract,
    type Guardian,
  } from "../utils/fetchGuardianProversFromContract";
  import { ethers } from "ethers";
  import {
    fetchAllGuardianProverRequests,
    fetchAllStats,
    fetchStats,
    type HealthCheck,
    type Stat,
  } from "../utils/fetchGuardianProverStats";
  let guardianProvers: Guardian[] = [];
  let stats: Stat[] = [];
  let healthChecks: HealthCheck[] = [];

  onMount(async () => {
    guardianProvers = await fetchGuardianProversFromContract(
      import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS,
      new ethers.providers.JsonRpcProvider(import.meta.env.VITE_RPC_URL)
    );

    healthChecks = await fetchAllGuardianProverRequests(
      import.meta.env.VITE_GUARDIAN_PROVER_API_URL
    );
    stats = await fetchAllStats(import.meta.env.VITE_GUARDIAN_PROVER_API_URL);

    console.log(healthChecks);
    console.log(stats);
  });
</script>

{#each guardianProvers as guardian}
  <div>
    {guardian.address}: {guardian.id}
  </div>
{/each}
