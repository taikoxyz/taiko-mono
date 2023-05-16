<script lang="ts">
  import { BigNumber, Contract, ethers } from "ethers";
  import { getLatestSyncedHeader } from "../../utils/getLatestSyncedHeader";
  import StatusIndicator from "../../components/StatusIndicator.svelte";
  import { watchHeaderSynced } from "../../utils/watchHeaderSynced";
  import { getPendingTransactions } from "../../utils/getPendingTransactions";
  import { getBlockFee } from "../../utils/getBlockFee";
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
  import TaikoL1 from "../../constants/abi/TaikoL1";
  import { getNumProvers } from "../../utils/getNumProvers";
  import { getNumProposers } from "../../utils/getNumProposers";
  import DetailsModal from "../../components/DetailsModal.svelte";
  import { addressSubsection } from "../../utils/addressSubsection";
  import { getEthDeposits } from "../../utils/getEthDeposits";
  import { getNextEthDepositToProcess } from "../../utils/getNextEthDepositToProcess";
  import { layerToDisplayName } from "../../utils/layerToDisplayName";
  import { layer } from "../../store/layer";
  import { Layer } from "../../domain/layer";

  let l1Provider: ethers.providers.JsonRpcProvider;
  let l2Provider: ethers.providers.JsonRpcProvider;
  let statusIndicators: StatusIndicatorProp[] = [];
  let l1TaikoAddress: string;
  let l2TaikoAddress: string;
  let l1ExplorerUrl: string;
  let l2ExplorerUrl: string;
  let oracleProverAddress: string;
  let eventIndexerApiUrl: string;
  let feeTokenSymbol: string;

  let proverDetailsOpen: boolean = false;
  let proposerDetailsOpen: boolean = false;

  function initConfig(layer: Layer) {
    l1Provider = new ethers.providers.JsonRpcProvider(
      layer === Layer.Two
        ? import.meta.env.VITE_L1_RPC_URL
        : import.meta.env.VITE_L2_RPC_URL
    );
    l2Provider = new ethers.providers.JsonRpcProvider(
      layer === Layer.Two
        ? import.meta.env.VITE_L2_RPC_URL
        : import.meta.env.VITE_L3_RPC_URL
    );

    l1TaikoAddress =
      layer === Layer.Two
        ? import.meta.env.VITE_L2_TAIKO_L1_ADDRESS
        : import.meta.env.VITE_L3_TAIKO_L1_ADDRESS;
    l2TaikoAddress =
      layer === Layer.Two
        ? import.meta.env.VITE_L2_TAIKO_L2_ADDRESS
        : import.meta.env.VITE_L3_TAIKO_L2_ADDRESS;
    l1ExplorerUrl = import.meta.env.VITE_L1_EXPLORER_URL;
    l2ExplorerUrl =
      layer === Layer.Two
        ? import.meta.env.VITE_L2_EXPLORER_URL
        : import.meta.env.VITE_L3_EXPLORER_URL;
    feeTokenSymbol = import.meta.env.VITE_FEE_TOKEN_SYMBOL || "TKO";
    oracleProverAddress =
      import.meta.env.ORACLE_PROVER_ADDRESS ||
      "0x1567CDAb5F7a69154e61A16D8Ff5eE6A3e991b39";
    eventIndexerApiUrl =
      layer === Layer.Two
        ? import.meta.env.VITE_L2_EVENT_INDEXER_API_URL
        : import.meta.env.VITE_L3_EVENT_INDEXER_API_URL;
    return {
      l1Provider,
      l2Provider,
      l1TaikoAddress,
      l2TaikoAddress,
      l1ExplorerUrl,
      l2ExplorerUrl,
      feeTokenSymbol,
      oracleProverAddress,
      eventIndexerApiUrl,
    };
  }

  function buildStatusIndicators(config: ReturnType<typeof initConfig>) {
    const indicators: StatusIndicatorProp[] = [
      {
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string
        ) => (await getNumProvers(config.eventIndexerApiUrl)).uniqueProvers,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "Unique Provers",
        intervalInMs: 0,
        colorFunc: (value: Status) => {
          return "green";
        },
        onClick: (value: Status) => {
          proverDetailsOpen = true;
        },
        tooltip:
          "The number of unique provers who successfully submitted a proof to the TaikoL1 smart contract.",
      },
      {
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string
        ) => (await getNumProposers(config.eventIndexerApiUrl)).uniqueProposers,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "Unique Proposers",
        intervalInMs: 0,
        colorFunc: (value: Status) => {
          return "green";
        },
        onClick: (value: Status) => {
          proposerDetailsOpen = true;
        },
        tooltip:
          "The number of unique proposers who successfully submitted a proposed block to the TaikoL1 smart contract.",
      },
      {
        statusFunc: getLatestSyncedHeader,
        watchStatusFunc: watchHeaderSynced,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "L1 Latest Synced Header",
        intervalInMs: 0,
        colorFunc: (value: Status) => {
          return "green";
        },
        onClick: (value: Status) => {
          window.open(
            `${config.l2ExplorerUrl}/block/${value.toString()}`,
            "_blank"
          );
        },
        tooltip:
          "The most recent Layer 2 Header that has been synchronized with the TaikoL1 smart contract.",
      },
      {
        statusFunc: getLatestSyncedHeader,
        watchStatusFunc: watchHeaderSynced,
        provider: config.l2Provider,
        contractAddress: config.l2TaikoAddress,
        header: "L2 Latest Synced Header",
        intervalInMs: 0,
        colorFunc: (value: Status) => {
          return "green";
        },
        onClick: (value: Status) => {
          window.open(
            `${config.l1ExplorerUrl}/block/${value.toString()}`,
            "_blank"
          );
        },
        tooltip:
          "The most recent Layer 1 Header that has been synchronized with the TaikoL2 smart contract. The headers are synchronized with every L2 block.",
      },
      {
        statusFunc: getPendingTransactions,
        watchStatusFunc: null,
        provider: config.l2Provider,
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
        provider: config.l2Provider,
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
        statusFunc: getAvailableSlots,
        watchStatusFunc: null,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
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
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
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
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
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
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "Unverified Blocks",
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
        statusFunc: getEthDeposits,
        watchStatusFunc: null,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "ETH Deposits",
        intervalInMs: 20000,
        colorFunc: (value: Status) => {
          if (BigNumber.from(value).eq(0)) {
            return "green";
          } else if (BigNumber.from(value).lt(32)) {
            return "yellow";
          } else {
            return "red";
          }
        },
        tooltip: "The number of pending ETH deposits for L1 => L2",
      },
      {
        statusFunc: getNextEthDepositToProcess,
        watchStatusFunc: null,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "Next ETH Deposit",
        intervalInMs: 20000,
        colorFunc: (value: Status) => {
          return "green";
        },
        tooltip: "The next ETH deposit that will be processed",
      },
      {
        statusFunc: getGasPrice,
        watchStatusFunc: null,
        provider: config.l2Provider,
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

    try {
      indicators.push({
        statusFunc: getBlockFee,
        watchStatusFunc: null,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "Block Fee",
        intervalInMs: 15000,
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip:
          "The current fee to propose a block to the TaikoL1 smart contract.",
      });
      indicators.push({
        statusFunc: getProofReward,
        watchStatusFunc: null,
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "Proof Reward",
        intervalInMs: 15000,
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip:
          "The current reward for successfully submitting a proof for a proposed block on the TaikoL1 smart contract.",
      });
      indicators.push({
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        header: "Latest Proof",
        intervalInMs: 0,
        status: "0",
        watchStatusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string,
          onEvent: (value: Status) => void
        ) => {
          const contract = new Contract(address, TaikoL1, provider);
          contract.on(
            "BlockProven",
            (
              id,
              parentHash,
              blockHash,
              signalRoot,
              prover,
              provenAt,
              ...args
            ) => {
              // ignore oracle prover
              if (prover.toLowerCase() !== oracleProverAddress.toLowerCase()) {
                onEvent(new Date().getTime().toString());
              }
            }
          );
        },
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        tooltip: "The most recent block proof submitted on TaikoL1 contract.",
      });

      indicators.push({
        provider: config.l1Provider,
        contractAddress: config.l1TaikoAddress,
        statusFunc: async (
          provider: ethers.providers.JsonRpcProvider,
          address: string
        ) => {
          const stateVars = await getStateVariables(provider, address);
          return `${stateVars.proofTimeIssued.toNumber() / 1000} seconds`;
        },
        colorFunc: function (status: Status) {
          return "green"; // todo: whats green, yellow, red?
        },
        header: "Average Proof Time",
        intervalInMs: 5 * 1000,
        tooltip:
          "The current average proof time, updated when a block is successfully proven.",
      });
    } catch (e) {
      console.error(e);
    }

    return indicators;
  }

  onMount(async () => {
    const config = initConfig($layer);

    statusIndicators = buildStatusIndicators(config);
  });

  async function toggleLayer() {
    const newLayer = $layer === Layer.Two ? Layer.Three : Layer.Two;
    layer.set(newLayer);

    statusIndicators = [];
    setTimeout(() => {
      statusIndicators = buildStatusIndicators(initConfig(newLayer));
    }, 1 * 500);
  }
</script>

<div class="text-center">
  <h1 class="text-2xl">Taiko Protocol Status</h1>
  <h2 class="cursor-pointer" on:click={toggleLayer}>
    {layerToDisplayName($layer)}
  </h2>
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

{#if proverDetailsOpen}
  <DetailsModal title={"Prover Details"} bind:isOpen={proverDetailsOpen}>
    <div
      class="grid grid-cols-2 gap-4 text-center my-10 max-h-96 overflow-y-auto"
      slot="body"
    >
      {#await getNumProvers(eventIndexerApiUrl) then provers}
        {#each provers.provers as prover}
          <a
            href="{l1ExplorerUrl}/address/{prover.address}"
            target="_blank"
            rel="noreferrer"
          >
            {addressSubsection(prover.address)}
          </a>
          <div>{prover.count}</div>
        {/each}
      {:catch error}
        <p class="red">{error.message}</p>
      {/await}
    </div>
  </DetailsModal>
{/if}

{#if proposerDetailsOpen}
  <DetailsModal title={"Prover Details"} bind:isOpen={proposerDetailsOpen}>
    <div
      class="grid grid-cols-2 gap-4 text-center my-10 max-h-96 overflow-y-auto"
      slot="body"
    >
      {#await getNumProposers(eventIndexerApiUrl) then proposers}
        {#each proposers.proposers as proposer}
          <a
            href="{l1ExplorerUrl}/address/{proposer.address}"
            target="_blank"
            rel="noreferrer"
          >
            {addressSubsection(proposer.address)}
          </a>
          <div>{proposer.count}</div>
        {/each}
      {:catch error}
        <p class="red">{error.message}</p>
      {/await}
    </div>
  </DetailsModal>
{/if}
