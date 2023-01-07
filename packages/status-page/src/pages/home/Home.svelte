<script lang="ts">
  import { BigNumber, ethers } from "ethers";
  import { getLatestSyncedHeader } from "../../utils/getLatestSyncedHeader";
  import StatusIndicator from "../../components/StatusIndicator.svelte";
  import { watchHeaderSynced } from "../../utils/watchHeaderSynced";
  import { getPendingTransactions } from "../../utils/getPendingTransactions";
  // import { getBlockFee } from "../../utils/getBlockFee";
  import { getIsHalted } from "../../utils/getIsHalted";
  import { getAvailableSlots } from "../../utils/getAvailableSlots";
  import { getPendingBlocks } from "../../utils/getPendingBlocks";
  import { getProposers } from "../../utils/getProposers";
  import { getLastVerifiedBlockId } from "../../utils/getLastVerifiedBlockId";
  import { getNextBlockId } from "../../utils/getNextBlockId";
  import { getGasPrice } from "../../utils/getGasPrice";
  import { getPeerCount } from "../../utils/getPeerCount";
  import { getQueuedTransactions } from "../../utils/getQueuedTransactions";

  export let l1Provider: ethers.providers.JsonRpcProvider;
  export let l1TaikoAddress: string;
  export let l2Provider: ethers.providers.JsonRpcProvider;
  export let l2TaikoAddress: string;

  const statusIndicators = [
    {
      statusFunc: getLatestSyncedHeader,
      watchStatusFunc: watchHeaderSynced,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "L1 Latest Synced Header",
      intervalInMs: 0,
      colorFunc: (value: string | number | boolean) => {
        return "green";
      },
    },
    {
      statusFunc: getLatestSyncedHeader,
      watchStatusFunc: watchHeaderSynced,
      provider: l2Provider,
      contractAddress: l2TaikoAddress,
      header: "L2 Latest Synced Header",
      intervalInMs: 0,
      colorFunc: (value: string | number | boolean) => {
        return "green";
      },
    },
    {
      statusFunc: getProposers,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Unique Proposers",
      intervalInMs: 0,
      colorFunc: (value: string | number | boolean) => {
        return "green";
      },
    },
    {
      statusFunc: getPendingTransactions,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: "",
      header: "Tx Mempool (pending)",
      intervalInMs: 10000,
      colorFunc: (value: string | number | boolean) => {
        if (BigNumber.from(value).gt(4000)) return "red";
        return "green";
      },
    },
    {
      statusFunc: getQueuedTransactions,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: "",
      header: "Tx Mempool (queued)",
      intervalInMs: 10000,
      colorFunc: (value: string | number | boolean) => {
        if (BigNumber.from(value).gt(4000)) return "red";
        return "green";
      },
    },
    // {
    //   statusFunc: getBlockFee,
    //   watchStatusFunc: null,
    //   provider: l1Provider,
    //   contractAddress: l1TaikoAddress,
    //   header: "Block Fee",
    //   intervalInMs: 5000,
    // },
    // {
    //   statusFunc: getProofReward,
    //   watchStatusFunc: null,
    //   provider: l1Provider,
    //   contractAddress: l1TaikoAddress,
    //   header: "Proof Reward",
    //   intervalInMs: 5000,
    // },
    {
      statusFunc: getIsHalted,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Is Halted",
      intervalInMs: 0,
      colorFunc: (value: string | number | boolean) => {
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
      intervalInMs: 10000,
      colorFunc: (value: string | number | boolean) => {
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
      intervalInMs: 10000,
      colorFunc: (value: string | number | boolean) => {
        return "green";
      },
    },
    {
      statusFunc: getNextBlockId,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Next Block ID",
      intervalInMs: 10000,
      colorFunc: (value: string | number | boolean) => {
        return "green";
      },
    },
    {
      statusFunc: getPendingBlocks,
      watchStatusFunc: null,
      provider: l1Provider,
      contractAddress: l1TaikoAddress,
      header: "Pending Blocks",
      intervalInMs: 10000,
      colorFunc: (value: string | number | boolean) => {
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
      intervalInMs: 10000,
      colorFunc: (value: string | number | boolean) => {
        return "green";
      },
    },
    {
      statusFunc: getPeerCount,
      watchStatusFunc: null,
      provider: l2Provider,
      contractAddress: l2TaikoAddress,
      header: "Peers",
      intervalInMs: 30000,
      colorFunc: (value: string | number | boolean) => {
        return "green";
      },
    },
  ];
</script>

<div class="text-center">
  <h1 class="text-2xl">Taiko Network Status</h1>
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
    />
  {/each}
</div>
