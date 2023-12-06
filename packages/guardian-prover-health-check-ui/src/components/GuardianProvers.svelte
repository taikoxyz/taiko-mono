<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import {
    fetchGuardianProversFromContract,
    type Guardian,
  } from "../utils/fetchGuardianProversFromContract";
  import { ethers } from "ethers";
  import {
    fetchGuardianProverRequests,
    fetchLatestGuardianProverRequest,
    fetchStats,
    type HealthCheck,
    type Stat,
  } from "../utils/fetchGuardianProverStats";

  let defaultSize: number = 10;
  let guardianProvers: Guardian[] = [];
  let stats: Stat[] = [];
  let healthChecks: HealthCheck[] = [];
  let activeId: number = 0;
  let nextHealthCheckPage: number = 0;
  let healthCheckPageTotal: number = 0;
  let statsPageTotal: number = 0;
  let nextStatsPage: number = 0;
  let activeSubTab: string = "healthchecks";
  let loading: boolean = false;
  let intervals: NodeJS.Timeout[] = [];

  onMount(async () => {
    loading = true;
    guardianProvers = await fetchGuardianProversFromContract(
      import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS,
      new ethers.providers.JsonRpcProvider(import.meta.env.VITE_RPC_URL)
    );

    await Promise.all(
      guardianProvers.map(async (p) => {
        const latest = await fetchLatestGuardianProverRequest(
          import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
          p.id
        );

        p.latestHealthCheck = latest;
        const interval = setInterval(async () => {
          const latest = await fetchLatestGuardianProverRequest(
            import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
            p.id
          );

          p.latestHealthCheck = latest;
          // alive if health check is 15 seconds old
          if (
            latest.alive &&
            latest.expectedAddress == latest.recoveredAddress &&
            Date.now() / 1000 -
              Date.parse(p.latestHealthCheck.createdAt) / 1000 >
              15
          ) {
            p.alive = false;
          } else {
            p.alive = true;
          }
          guardianProvers = guardianProvers;
        }, 12 * 1000);

        intervals.push(interval);
      })
    );

    await toggleTab(guardianProvers[0].id);
  });

  onDestroy(() => {
    intervals.map((i) => clearInterval(i));
  });

  async function fetchPrevHealthCheckPage(guardianProverId: number) {
    nextHealthCheckPage--;

    const page = await fetchGuardianProverRequests(
      import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
      nextHealthCheckPage,
      defaultSize,
      guardianProverId
    );

    healthCheckPageTotal = page.total_pages;
    healthChecks = page.items;
  }

  async function fetchNextHealthCheckPage(guardianProverId: number) {
    const page = await fetchGuardianProverRequests(
      import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
      nextHealthCheckPage,
      defaultSize,
      guardianProverId
    );

    healthCheckPageTotal = page.total_pages;
    healthChecks = page.items;

    nextHealthCheckPage++;
  }

  async function fetchPrevStatsPage(guardianProverId: number) {
    nextStatsPage--;

    const page = await fetchStats(
      import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
      nextStatsPage,
      defaultSize,
      guardianProverId
    );

    statsPageTotal = page.total_pages;
    stats = page.items;
  }

  async function fetchNextStatsPage(guardianProverId: number) {
    const page = await fetchStats(
      import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
      nextStatsPage,
      defaultSize,
      guardianProverId
    );

    statsPageTotal = page.total_pages;
    stats = page.items;

    nextStatsPage++;
  }

  async function toggleTab(guardianProverId: number) {
    loading = true;
    nextHealthCheckPage = 0;
    healthCheckPageTotal = 0;
    statsPageTotal = 0;
    nextStatsPage = 0;

    activeId = guardianProverId;
    await fetchNextHealthCheckPage(guardianProverId);

    console.log(healthChecks);
    await fetchNextStatsPage(guardianProverId);
    loading = false;
  }

  async function toggleSubTab(tab: string) {
    loading = true;
    activeSubTab = tab;
    loading = false;
  }
</script>

<h2 class="text-xl">Guardian Provers</h2>
<div class="tabs">
  {#each guardianProvers as guardian}
    <a
      class="tab {activeId === guardian.id ? 'tab-active' : ''} {guardian.alive
        ? 'green'
        : 'red'}"
      on:click={async () => await toggleTab(guardian.id)}>{guardian.id}</a
    >
  {/each}
</div>

{#each guardianProvers as guardian}
  {#if guardian.id === activeId}
    <div class="tabs">
      <a
        class="tab {activeSubTab === 'healthchecks' ? 'tab-active' : ''}"
        on:click={() => toggleSubTab("healthchecks")}>Health Checks</a
      >
      <a
        class="tab {activeSubTab === 'stats' ? 'tab-active' : ''}"
        on:click={() => toggleSubTab("stats")}>Stats</a
      >
    </div>
    {#if activeSubTab === "healthchecks"}
      <div class="overflow-x-auto">
        <table class="table">
          <!-- head -->
          <thead>
            <tr>
              <th>Alive</th>
              <th>Expected Address</th>
              <th>Recovered Address</th>
              <th>CreatedAt</th>
            </tr>
          </thead>
          <tbody>
            {#each healthChecks as healthCheck}
              <tr>
                <th>{healthCheck.alive}</th>
                <td>{healthCheck.expectedAddress}</td>
                <td>{healthCheck.recoveredAddress}</td>
                <td>{healthCheck.createdAt}</td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
      {#if nextHealthCheckPage - 1 !== 0}
        <button
          class="btn"
          on:click={async () => await fetchPrevHealthCheckPage(guardian.id)}
          >Prev</button
        >
      {/if}
      {#if nextHealthCheckPage !== healthCheckPageTotal}
        <button
          class="btn"
          on:click={async () => await fetchNextHealthCheckPage(guardian.id)}
          >Next</button
        >
      {/if}
    {:else if activeSubTab === "stats"}
      <div class="overflow-x-auto">
        <h2>Address: {guardian.address}</h2>
        <table class="table">
          <!-- head -->
          <thead>
            <tr>
              <th>Date</th>
              <th>Reqs</th>
              <th>Successful Reqs</th>
              <th>Uptime</th>
            </tr>
          </thead>
          <tbody>
            {#each stats as stat}
              <tr>
                <th>{stat.date}</th>
                <td>{stat.requests}</td>
                <td>{stat.successfulRequests}</td>
                <td>{stat.uptime}%</td>
              </tr>
            {/each}
          </tbody>
        </table>
        {#if nextStatsPage - 1 !== 0}
          <button
            class="btn"
            on:click={async () => await fetchPrevStatsPage(guardian.id)}
            >Prev</button
          >
        {/if}
      </div>
      {#if nextStatsPage !== statsPageTotal}
        <button
          class="btn"
          on:click={async () => await fetchNextStatsPage(guardian.id)}
          >Next</button
        >
      {/if}
    {:else}
      Blocks
    {/if}
  {/if}
{/each}

<style>
  .red {
    color: red;
  }

  .green {
    color: green;
  }
</style>
