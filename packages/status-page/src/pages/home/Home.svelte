<script lang="ts">
  import { BigNumber, Contract, ethers } from "ethers";
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
  import type { Status, StatusIndicatorProp } from "../../domain/status";
  import { getStateVariables } from "../../utils/getStateVariables";
  import { truncateString } from "../../utils/truncateString";
  import TaikoL1 from "../../constants/abi/TaikoL1";

  export let l1Provider: ethers.providers.JsonRpcProvider;
  export let l1TaikoAddress: string;
  export let l2Provider: ethers.providers.JsonRpcProvider;
  export let l2TaikoAddress: string;
  export let l1ExplorerUrl: string;
  export let l2ExplorerUrl: string;
  export let feeTokenSymbol: string;

  let statusIndicators: StatusIndicatorProp[] = [
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
      tooltip:
        "The most recent Layer 2 Header that has been synchronized with the TaikoL1 smart contract.",
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
      tooltip:
        "The most recent Layer 1 Header that has been synchronized with the TaikoL2 smart contract. The headers are synchronized with every L2 block.",
    },
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
      tooltip: "Whether the Taiko smart contract on Layer 1 has been halted.",
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
      tooltip:
        "The amount of slots for proposed blocks on the TaikoL1 smart contract. When this number is 0, no blocks can be proposed until a block has been proven.",
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
      tooltip:
        "The most recently verified Layer 2 block on the TaikoL1 smart contract.",
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
      tooltip:
        "The ID that the next proposed block on the TaikoL1 smart contract will receive.",
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
      tooltip:
        "The amount of pending proposed blocks that have not been proven on the TaikoL1 smart contract.",
    },
    {
      statusFunc: getGasPrice,
      watchStatusFunc: null,
      provider: l2Provider,
      contractAddress: "",
      header: "Gas Price (gwei)",
      intervalInMs: 20000,
      colorFunc: (value: Status) => {
        return "green";
      },
      tooltip:
        "The current recommended gas price for a transaction on Layer 2.",
    },
  ];

  onMount(async () => {
    try {
      statusIndicators.push({
        statusFunc: getBlockFee,
        watchStatusFunc: null,
        provider: l1Provider,
        contractAddress: l1TaikoAddress,
        header: "Block Fee",
        intervalInMs: 15000,
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip:
          "The current fee to propose a block to the TaikoL1 smart contract.",
      });

      statusIndicators.push({
        statusFunc: getProofReward,
        watchStatusFunc: null,
        provider: l1Provider,
        contractAddress: l1TaikoAddress,
        header: "Proof Reward",
        intervalInMs: 15000,
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip:
          "The current reward for successfully submitting a proof for a proposed block on the TaikoL1 smart contract.",
      });
    } catch (e) {
      console.error(e);
    }

    try {
      statusIndicators.push({
        provider: l1Provider,
        contractAddress: l1TaikoAddress,
        header: "Latest Proposal",
        intervalInMs: 5 * 1000,
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string
        ) => {
          const stateVars = await getStateVariables(provider, address);
          return new Date(
            stateVars.lastProposedAt.toNumber() * 1000
          ).toString();
        },
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip: "The most recent block proposal on TaikoL1 contract.",
      });

      statusIndicators.push({
        provider: l1Provider,
        contractAddress: l1TaikoAddress,
        header: "Latest Proof",
        intervalInMs: 0,
        status: "0",
        watchStatusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string,
          onEvent: (value: Status) => void
        ) => {
          const contract = new Contract(address, TaikoL1, provider);
          contract.on("BlockProven", (id, parentHash, blockHash, timestamp) => {
            console.log("block proven", timestamp);
            onEvent(new Date(timestamp).toString());
          });
        },
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip: "The most recent block proof submitted on TaikoL1 contract.",
      });

      statusIndicators.push({
        provider: l1Provider,
        contractAddress: l1TaikoAddress,
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string
        ) => {
          const stateVars = await getStateVariables(provider, address);
          return stateVars.avgProofTime.toNumber();
        },
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        header: "Average Proof Time",
        intervalInMs: 5 * 1000,
        tooltip:
          "The current average proof time, updated when a block is successfully proven.",
      });

      statusIndicators.push({
        provider: l1Provider,
        contractAddress: l1TaikoAddress,
        header: "Average Block Time",
        intervalInMs: 5 * 1000,
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string
        ) => {
          const stateVars = await getStateVariables(provider, address);
          return stateVars.avgBlockTime.toNumber();
        },
        tooltip:
          "The current average block time, updated when a block is successfully proposed.",
      });

      statusIndicators.push({
        provider: l1Provider,
        contractAddress: l1TaikoAddress,
        header: "Fee Base",
        intervalInMs: 0,
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string
        ) => {
          const stateVars = await getStateVariables(provider, address);
          return `${truncateString(
            ethers.utils.formatEther(stateVars.feeBase),
            6
          )} ${feeTokenSymbol}`;
        },
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip: "The current fee base for proposing and rewarding",
      });
    } catch (e) {
      console.error(e);
    }

    statusIndicators = statusIndicators;
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
      tooltip={statusIndicator.tooltip}
      status={statusIndicator.status}
    />
  {/each}
</div>
