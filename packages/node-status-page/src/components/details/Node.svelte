<script lang="ts">
  import { BigNumber, ethers } from "ethers";
  import StatusIndicator from "../StatusIndicator.svelte";
  import { getPendingTransactions } from "../../utils/getPendingTransactions";
  import type { Status, StatusIndicatorProp } from "../../domain/status";
  import { getQueuedTransactions } from "../../utils/getQueuedTransactions";
  import { getSyncing } from "../../utils/getSyncing";
  import { onMount } from "svelte";

  export let l1Provider: ethers.providers.JsonRpcProvider;
  export let l1TaikoAddress: string;
  export let l2Provider: ethers.providers.JsonRpcProvider;

  let statusIndicators: StatusIndicatorProp[] = [
    {
      statusFunc: getPendingTransactions,
      watchStatusFunc: null,
      provider: l2Provider,
      contractAddress: "",
      header: "Tx Mempool (pending)",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        if (BigNumber.from(value).gt(4000)) return "red";
        return "green";
      },
      tooltip:
        "The current processable transactions in the mempool that have not been added to a block yet.",
    },
    {
      statusFunc: getQueuedTransactions,
      watchStatusFunc: null,
      provider: l2Provider,
      contractAddress: "",
      header: "Tx Mempool (queued)",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        if (BigNumber.from(value).gt(4000)) return "red";
        return "green";
      },
      tooltip:
        "The current transactions in the mempool where the transaction nonce is not in sequence. They are currently non-processable.",
    },
  ];

  onMount(async () => {
    const syncing = await getSyncing(l2Provider);
    statusIndicators.push({
      status: syncing.synced ? "synced" : "syncing",
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        contractAddress: string
      ) => {
        const s = await getSyncing(l2Provider);
        return s.synced ? "synced" : "syncing";
      },
      watchStatusFunc: null,
      provider: l2Provider,
      contractAddress: "",
      header: "Sync Status",
      intervalInMs: 5000,
      colorFunc: (value: Status) => {
        if (value === "synced") return "green";
        return "red";
      },
      tooltip: "Whether the node is currently syncing.",
    });

    if (!syncing.synced) {
      statusIndicators.push({
        status: syncing.currentBlock,
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          contractAddress: string
        ) => {
          const s = await getSyncing(l2Provider);
          return s.currentBlock;
        },
        watchStatusFunc: null,
        provider: l2Provider,
        contractAddress: "",
        header: "Current Block Sync Status",
        intervalInMs: 3000,
        colorFunc: (value: Status) => {
          return "green";
        },
        tooltip: "Current Block Sync Status",
      });

      statusIndicators.push({
        status: syncing.highestBlock,
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          contractAddress: string
        ) => {
          const s = await getSyncing(l2Provider);
          return s.currentBlock;
        },
        watchStatusFunc: null,
        provider: l2Provider,
        contractAddress: "",
        header: "Highest Block Sync Status",
        intervalInMs: 3000,
        colorFunc: (value: Status) => {
          return "green";
        },
        tooltip: "Highest Block Sync Status",
      });
    }

    statusIndicators = statusIndicators;
  });
</script>

<div class="text-center">
  <h1 class="text-2xl">Node Details</h1>
</div>

<div
  class="grid grid-cols-1 sm:grid-cols-3 md:grid-cols-5 gap-4 text-center my-10"
>
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
</div>
