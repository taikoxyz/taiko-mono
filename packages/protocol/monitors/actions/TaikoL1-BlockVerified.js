const { ethers } = require("ethers");
const { Defender } = require("@openzeppelin/defender-sdk");

const ABI = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "blockId",
        type: "uint256",
      },
      {
        indexed: true,
        internalType: "address",
        name: "prover",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "blockHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "stateRoot",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "tier",
        type: "uint16",
      },
    ],
    name: "BlockVerified",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "blockId",
        type: "uint256",
      },
      {
        indexed: true,
        internalType: "address",
        name: "prover",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "blockHash",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "bytes32",
        name: "stateRoot",
        type: "bytes32",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "tier",
        type: "uint16",
      },
    ],
    name: "BlockVerifiedV2",
    type: "event",
  },
];

function alertOrg(notificationClient, message) {
  notificationClient.send({
    channelAlias: "discord_blocks",
    subject: "🚨 TaikoL1: BlockVerified Alert",
    message,
  });
}

async function getLatestBlockNumber(provider) {
  const currentBlock = await provider.getBlock("latest");
  return currentBlock.number;
}

async function fetchLogsFromL1(
  eventNames,
  fromBlock,
  toBlock,
  address,
  abi,
  provider,
) {
  const iface = new ethers.utils.Interface(abi);
  const eventTopics = eventNames.map((eventName) =>
    iface.getEventTopic(eventName),
  );

  console.log(`eventTopics: ${eventTopics}`);

  try {
    const logs = await provider.getLogs({
      address,
      fromBlock,
      toBlock,
      topics: [eventTopics],
    });

    return logs.map((log) => iface.parseLog(log));
  } catch (error) {
    console.error("Error fetching L1 logs:", error);
    return [];
  }
}

function createProvider(apiKey, apiSecret, relayerApiKey, relayerApiSecret) {
  const client = new Defender({
    apiKey,
    apiSecret,
    relayerApiKey,
    relayerApiSecret,
  });

  return client.relaySigner.getProvider();
}

async function calculateBlockTime(provider) {
  const latestBlock = await provider.getBlock("latest");
  const previousBlock = await provider.getBlock(latestBlock.number - 100);

  const timeDiff = latestBlock.timestamp - previousBlock.timestamp;
  const blockDiff = latestBlock.number - previousBlock.number;

  const blockTime = timeDiff / blockDiff;
  return blockTime;
}

exports.handler = async function (event, context) {
  const { notificationClient } = context;
  const { apiKey, apiSecret, taikoL1ApiKey, taikoL1ApiSecret } = event.secrets;

  const taikoL1Provider = createProvider(
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret,
  );

  const currentBlockNumber = await getLatestBlockNumber(taikoL1Provider);
  const blockTimeInSeconds = await calculateBlockTime(taikoL1Provider);
  const blocksInFiveMinutes = Math.floor((5 * 60) / blockTimeInSeconds);

  const fromBlock = currentBlockNumber - blocksInFiveMinutes;
  const toBlock = currentBlockNumber;

  const logs = await fetchLogsFromL1(
    ["BlockVerified", "BlockVerifiedV2"],
    fromBlock,
    toBlock,
    "0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a",
    ABI,
    taikoL1Provider,
  );

  if (logs.length === 0) {
    alertOrg(
      notificationClient,
      `@davidcai @yuea7583 No BlockVerified event detected in the last 30 mins in TaikoL1!`,
    );
  }

  return true;
};
