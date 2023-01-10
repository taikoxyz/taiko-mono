<script lang="ts">
  import { BigNumber, ethers } from "ethers";
  import { getLatestSyncedHeader } from "../../utils/getLatestSyncedHeader";
  import StatusIndicator from "../../components/StatusIndicator.svelte";
  import { watchHeaderSynced } from "../../utils/watchHeaderSynced";
  import { getPendingTransactions } from "../../utils/getPendingTransactions";
  import { getBlockFee } from "../../utils/getBlockFee";
  import { getIsHalted } from "../../utils/getIsHalted";
  import { getAvailableSlots } from "../../utils/getAvailableSlots";
  import { getPendingBlocks } from "../../utils/getPendingBlocks";
  import { getLastVerifiedBlockId } from "../../utils/getLastVerifiedBlockId";
  import { getNextBlockId } from "../../utils/getNextBlockId";
  import { getGasPrice } from "../../utils/getGasPrice";
  import { getQueuedTransactions } from "../../utils/getQueuedTransactions";
  import { onMount } from "svelte";
  import { getProofReward } from "../../utils/getProofReward";
  import type Status from "../../domain/status";

  export let l1Provider: ethers.providers.JsonRpcProvider;
  export let l1TaikoAddress: string;
  export let l2Provider: ethers.providers.JsonRpcProvider;
  export let l2TaikoAddress: string;
  export let isTokenomicsEnabled: boolean = false;
  export let l1ExplorerUrl: string;
  export let l2ExplorerUrl: string;

  const statusIndicators = [
    {
      statusFunc: getLatestSyncedHeader,
      watchStatusFunc: watchHeaderSynced,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "L1 Latest Synced Header",
      intervalInMs: 0,
      colorFunc: (value: Status) => {
        return "green";
      },
      onClick: (value: Status) => {
        window.open(`${l2ExplorerUrl}/block/${value.toString()}`, "_blank");
      },
    },
    {
      statusFunc: getLatestSyncedHeader,
      watchStatusFunc: watchHeaderSynced,
      provider: l2Provider,
      contractAddress: l2TaikoAddress,
      header: "L2 Latest Synced Header",
      intervalInMs: 0,
      colorFunc: (value: Status) => {
        return "green";
      },
      onClick: (value: Status) => {
        window.open(`${l1ExplorerUrl}/block/${value.toString()}`, "_blank");
      },
    },
    // {
    //   statusFunc: getProposers,
    //   watchStatusFunc: null,
    //   provider: l1Provider,
    //   contractAddress: l1TaikoAddress,
    //   header: "Unique Proposers",
    //   intervalInMs: 0,
    //   colorFunc: (value: Status) => {
    //     return "green";
    //   },
    // },
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
    },
    {
      statusFunc: getIsHalted,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Is Halted",
      intervalInMs: 0,
      colorFunc: (value: Status) => {
        if (value.toString() === "true") return "red";
        return "green";
      },
    },
    {
      statusFunc: getAvailableSlots,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Available Slots",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        if (BigNumber.from(value).eq(0)) return "red";
        return "green";
      },
    },
    {
      statusFunc: getLastVerifiedBlockId,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Last Verified Block ID",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        return "green";
      },
    },
    {
      statusFunc: getNextBlockId,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Next Block ID",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        return "green";
      },
    },
    {
      statusFunc: getPendingBlocks,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Pending Blocks",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        if (BigNumber.from(value).eq(0)) {
          return "red";
        } else if (BigNumber.from(value).lt(5)) {
          return "yellow";
        } else {
          return "green";
        }
      },
    },
    {
      statusFunc: getGasPrice,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Gas Price (gwei)",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        return "green";
      },
    },
  ];

  onMount(() => {
    if (isTokenomicsEnabled) {
      statusIndicators.push({
        statusFunc: getBlockFee,
        watchStatusFunc: null,
        provider: l2Provider,
        contractAddress: l2TaikoAddress,
        header: "Block Fee",
        intervalInMs: 15000,
        colorFunc: null,
      });

      statusIndicators.push({
        statusFunc: getProofReward,
        watchStatusFunc: null,
        provider: l2Provider,
        contractAddress: l2TaikoAddress,
        header: "Proof Reward",
        intervalInMs: 15000,
        colorFunc: null,
      });
    }
  });
</script>

<div class="text-center">
  <h1 class="text-2xl">Taiko Protocol Status</h1>
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
    />
  {/each}
</div>
