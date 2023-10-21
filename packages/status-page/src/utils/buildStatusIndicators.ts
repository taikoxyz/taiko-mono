import { BigNumber, Contract, ethers } from "ethers";
import TaikoToken from "../constants/abi/TaikoToken";
import TaikoL1 from "../constants/abi/TaikoL1";
import type { Status, StatusIndicatorProp } from "../domain/status";
import { getAvailableSlots } from "./getAvailableSlots";
import type { StatsResponse } from "./getAverageProofReward";
import { getAverageProofTime } from "./getAverageProofTime";
import { getEthDeposits } from "./getEthDeposits";
import { getGasPrice } from "./getGasPrice";
import { getLastVerifiedBlockId } from "./getLastVerifiedBlockId";
import { getLatestSyncedHeader } from "./getLatestSyncedHeader";
import { getNextBlockId } from "./getNextBlockId";
import { getNextEthDepositToProcess } from "./getNextEthDepositToProcess";
import { getNumProposers } from "./getNumProposers";
import { getNumProvers } from "./getNumProvers";
import { getPendingBlocks } from "./getPendingBlocks";
import { getPendingTransactions } from "./getPendingTransactions";
import { getQueuedTransactions } from "./getQueuedTransactions";
import type { initConfig } from "./initConfig";
import { watchHeaderSynced } from "./watchHeaderSynced";
import axios from "axios";
import { getStateVariables } from "./getStateVariables";

export async function buildStatusIndicators(
  config: ReturnType<typeof initConfig>,
  onProverClick: (value: Status) => void,
  onProposerClick: (value: Status) => void
) {
  const tko: Contract = new Contract(
    config.taikoTokenAddress,
    TaikoToken,
    config.l1Provider
  );

  let decimals: number = 8;

  try {
    decimals = await tko.decimals();
  } catch (e) {}

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
      onClick: onProverClick,
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
      onClick: onProposerClick,
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
        // if (BigNumber.from(value).eq(0)) {
        //   return "green";
        // } else if (BigNumber.from(value).lt(32)) {
        //   return "yellow";
        // } else {
        //   return "red";
        // }
        return "green";
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
      intervalInMs: 30000,
      colorFunc: (value: Status) => {
        return "green";
      },
      tooltip:
        "The current recommended gas price for a transaction on Layer 2.",
    },
    {
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        contractAddress: string
      ): Promise<string> => {
        const latestBlock = await provider.getBlock("latest");
        return `${ethers.utils.formatUnits(latestBlock.baseFeePerGas, "gwei")}`;
      },
      watchStatusFunc: null,
      provider: config.l2Provider,
      contractAddress: config.l2TaikoAddress,
      header: "L2 EIP1559 BaseFee (gwei)",
      intervalInMs: 30000,
      colorFunc: (value: Status) => {
        return "green";
      },
      tooltip:
        "The current base fee for an L2 transaction with EIP1559-enabled.",
    },
    {
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        contractAddress: string
      ): Promise<string> => {
        const feeData = await provider.getFeeData();
        return `${ethers.utils.formatUnits(
          feeData.maxPriorityFeePerGas,
          "gwei"
        )}`;
      },
      watchStatusFunc: null,
      provider: config.l2Provider,
      contractAddress: config.l2TaikoAddress,
      header: "L2 EIP1559 Recommended MaxPriorityFeePerGas (gwei)",
      intervalInMs: 30000,
      colorFunc: (value: Status) => {
        return "green";
      },
      tooltip:
        "The current recommend max priority fee per gas for a fast transaction.",
    },
  ];

  try {
    indicators.push({
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        contractAddress: string
      ): Promise<string> => {
        const contract: Contract = new Contract(
          contractAddress,
          TaikoL1,
          provider
        );
        const fee = await contract.getBlockFee();
        return `${ethers.utils.formatUnits(fee, decimals)} ${
          config.feeTokenSymbol
        }`;
      },
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
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        contractAddress: string
      ): Promise<string> => {
        const contract: Contract = new Contract(
          contractAddress,
          TaikoL1,
          provider
        );
        const latestBlockNumber = await provider.getBlockNumber();
        const eventFilter = contract.filters.BlockVerified();
        const events = await contract.queryFilter(
          eventFilter,
          latestBlockNumber - 200,
          latestBlockNumber
        );

        if (!events || events.length === 0) {
          return `0 ${config.feeTokenSymbol}`;
        }

        const event = events[events.length - 1].args as any as {
          reward: BigNumber;
        };

        return `${ethers.utils.formatUnits(
          event.reward.toString(),
          decimals
        )} ${config.feeTokenSymbol}`;
      },
      watchStatusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        address: string,
        onEvent: (value: Status) => void
      ) => {
        const contract = new Contract(address, TaikoL1, provider);
        const listener = (id, blockHash, reward, ...args) => {
          onEvent(
            `${ethers.utils.formatUnits(reward.toString(), decimals)} ${
              config.feeTokenSymbol
            }`
          );
        };
        contract.on("BlockVerified", listener);

        return () => contract.off("BlockVerified", listener);
      },
      provider: config.l1Provider,
      contractAddress: config.l1TaikoAddress,
      header: "Latest Proof Reward",
      intervalInMs: 0,
      colorFunc: function (status: Status) {
        return "green"; // todo: whats green, yellow, red?
      },
      tooltip: "The most recent proof reward, updated on block being verified.",
    });
    indicators.push({
      provider: config.l1Provider,
      contractAddress: config.l1TaikoAddress,
      header: "Latest Proof Time",
      intervalInMs: 0,
      status: "0",
      watchStatusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        address: string,
        onEvent: (value: Status) => void
      ) => {
        const contract = new Contract(address, TaikoL1, provider);
        const listener = async (
          id,
          parentHash,
          blockHash,
          signalRoot,
          prover,
          parentGasUsed,
          event
        ) => {
          if (
            prover.toLowerCase() !== config.oracleProverAddress.toLowerCase() &&
            prover.toLowerCase() !== config.systemProverAddress.toLowerCase()
          ) {
            const proposedBlock = await contract.getBlock(id);
            const block = await event.getBlock();
            const proofTime =
              block.timestamp - proposedBlock._proposedAt.toNumber();

            onEvent(`${proofTime} seconds`);
          }
        };
        contract.on("BlockProven", listener);

        return () => {
          contract.off("BlockProven", listener);
        };
      },
      colorFunc: function (status: Status) {
        return "green"; // todo: whats green, yellow, red?
      },
      tooltip: "The most recent block proof submitted on TaikoL1 contract.",
    });
    indicators.push({
      provider: config.l1Provider,
      contractAddress: config.l1TaikoAddress,
      header: "Latest Oracle Proof",
      intervalInMs: 0,
      status: "0",
      watchStatusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        address: string,
        onEvent: (value: Status) => void
      ) => {
        const contract = new Contract(address, TaikoL1, provider);
        const listener = async (
          id,
          parentHash,
          blockHash,
          signalRoot,
          prover,
          parentGasUsed,
          event
        ) => {
          if (
            prover.toLowerCase() === config.systemProverAddress.toLowerCase()
          ) {
            const block = await event.getBlock();

            onEvent(`${new Date(block.timestamp * 1000).toUTCString()}`);
          }
        };
        contract.on("BlockProven", listener);

        return () => {
          contract.off("BlockProven", listener);
        };
      },
      colorFunc: function (status: Status) {
        return "green"; // todo: whats green, yellow, red?
      },
      tooltip: "The timestamp of the latest oracle proof",
    });

    indicators.push({
      provider: config.l1Provider,
      contractAddress: config.l1TaikoAddress,
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        address: string
      ) => {
        const config = await getStateVariables(provider, address);
        return config.proofTimeTarget.toNumber();
      },
      colorFunc: function (status: Status) {
        return "green";
      },
      header: "Proof Time Target (seconds)",
      intervalInMs: 5 * 1000,
      tooltip:
        "The proof time target the protocol intends the average proof time to be",
    });

    indicators.push({
      provider: config.l1Provider,
      contractAddress: config.l1TaikoAddress,
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        address: string
      ) => await getAverageProofTime(config.eventIndexerApiUrl),
      colorFunc: function (status: Status) {
        return "green";
      },
      header: "Average Proof Time (seconds)",
      intervalInMs: 5 * 1000,
      tooltip:
        "The current average proof time, updated when a block is successfully proven.",
    });

    indicators.push({
      provider: config.l1Provider,
      contractAddress: config.l1TaikoAddress,
      statusFunc: async (
        provider: ethers.providers.JsonRpcProvider,
        contractAdress: string
      ) => {
        const resp = await axios.get<StatsResponse>(
          `${config.eventIndexerApiUrl}/stats`
        );
        return `${ethers.utils.formatUnits(
          resp.data.averageProofReward,
          decimals
        )} ${config.feeTokenSymbol}`;
      },
      colorFunc: function (status: Status) {
        return "green";
      },
      header: "Average Proof Reward",
      intervalInMs: 5 * 1000,
      tooltip:
        "The current average proof reward, updated when a block is successfully verified.",
    });
  } catch (e) {
    console.error(e);
  }

  return indicators;
}
