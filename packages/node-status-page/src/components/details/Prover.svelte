<script lang="ts">
  import type { ethers } from "ethers";
  import type { Status, StatusIndicatorProp } from "../../domain/status";
  import { getEthBalance } from "../../utils/getEthBalance";
  import { onMount } from "svelte";
  import StatusIndicator from "../StatusIndicator.svelte";

  export let l1Provider: ethers.providers.JsonRpcProvider;
  export let l1TaikoAddress: string;
  export let l2Provider: ethers.providers.JsonRpcProvider;
  export let proverAddress: string;

  let activeTab: string = "status";

  let statusIndicators: StatusIndicatorProp[] = [
    {
      statusFunc: async () => {
        return `${await getEthBalance(l1Provider, proverAddress)} ETH`;
      },
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: "",
      header: "ETH Balance (L1)",
      intervalInMs: 0,
      colorFunc: (value: Status) => {
        return "green";
      },
      tooltip: "Current L1 ETH balance of prover address",
    },
  ];
</script>

<div class="text-center">
  <h1 class="text-2xl">Prover Details</h1>

  <div class="text-center mt-4 mb-4">
    <div class="tabs">
      <a
        class="tab tab tab-lifted"
        class:tab-active={activeTab === "status"}
        on:click={() => (activeTab = "status")}>Status</a
      >

      <a
        class="tab tab tab-lifted"
        class:tab-active={activeTab === "rewards"}
        on:click={() => (activeTab = "rewards")}>Rewards</a
      >
    </div>
  </div>

  {#if activeTab === "status"}
    {#each statusIndicators as statusIndicator}
      <StatusIndicator
        statusFunc={statusIndicator.statusFunc}
        watchStatusFunc={statusIndicator.watchStatusFunc}
        provider={statusIndicator.provider}
        contractAddress={statusIndicator.contractAddress}
        header={statusIndicator.header}
        colorFunc={statusIndicator.colorFunc}
        onClick={statusIndicator.onClick}
        intervalInMs={statusIndicator.intervalInMs}
        tooltip={statusIndicator.tooltip}
        status={statusIndicator.status}
      />
    {/each}
  {:else}
    <div class="text-center card w-96 bg-base-100 shadow-xl">
      <div class="card-body">
        Rewards:
        <p>0</p>
        <div class="card-actions justify-end">
          <button class="btn btn-primary">Claim</button>
        </div>
      </div>
    </div>
  {/if}
</div>
