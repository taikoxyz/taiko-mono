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
  import guardianProver from "../abi/guardianProver";
  let guardianProvers: Guardian[] = [];
  let stats: Stat[] = [];
  let healthChecks: HealthCheck[] = [];

  onMount(async () => {
    const getGuardianProvers = async () => {
      guardianProvers = await fetchGuardianProversFromContract(
        import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS,
        new ethers.providers.JsonRpcProvider(import.meta.env.VITE_RPC_URL)
      );
    };

    const getHealthChecks = async () => {
      healthChecks = await fetchAllGuardianProverRequests(
        import.meta.env.VITE_GUARDIAN_PROVER_API_URL
      );
    };

    const getStats = async () => {
      stats = await fetchAllStats(import.meta.env.VITE_GUARDIAN_PROVER_API_URL);
    };

    await Promise.all([getGuardianProvers, getHealthChecks, getStats]);
  });
</script>

{#if guardianProver.length && stats.length && healthChecks.length}
  {#each guardianProvers as guardian}
    <h2>Guardian Provers</h2>
    <div>
      {guardian.address}: {guardian.id}
    </div>
  {/each}
{:else}
  Loading
{/if}
