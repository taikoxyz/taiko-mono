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
        name: "assignedProver",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint96",
        name: "livenessBond",
        type: "uint96",
      },
      {
        components: [
          {
            internalType: "bytes32",
            name: "l1Hash",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "difficulty",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "blobHash",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "extraData",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "depositsHash",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "coinbase",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "id",
            type: "uint64",
          },
          {
            internalType: "uint32",
            name: "gasLimit",
            type: "uint32",
          },
          {
            internalType: "uint64",
            name: "timestamp",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "l1Height",
            type: "uint64",
          },
          {
            internalType: "uint16",
            name: "minTier",
            type: "uint16",
          },
          {
            internalType: "bool",
            name: "blobUsed",
            type: "bool",
          },
          {
            internalType: "bytes32",
            name: "parentMetaHash",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
        ],
        indexed: false,
        internalType: "struct TaikoData.BlockMetadata",
        name: "meta",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "address",
            name: "recipient",
            type: "address",
          },
          {
            internalType: "uint96",
            name: "amount",
            type: "uint96",
          },
          {
            internalType: "uint64",
            name: "id",
            type: "uint64",
          },
        ],
        indexed: false,
        internalType: "struct TaikoData.EthDeposit[]",
        name: "depositsProcessed",
        type: "tuple[]",
      },
    ],
    name: "BlockProposed",
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
        name: "assignedProver",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint96",
        name: "livenessBond",
        type: "uint96",
      },
      {
        components: [
          {
            internalType: "bytes32",
            name: "l1Hash",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "difficulty",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "blobHash",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "extraData",
            type: "bytes32",
          },
          {
            internalType: "bytes32",
            name: "depositsHash",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "coinbase",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "id",
            type: "uint64",
          },
          {
            internalType: "uint32",
            name: "gasLimit",
            type: "uint32",
          },
          {
            internalType: "uint64",
            name: "timestamp",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "l1Height",
            type: "uint64",
          },
          {
            internalType: "uint16",
            name: "minTier",
            type: "uint16",
          },
          {
            internalType: "bool",
            name: "blobUsed",
            type: "bool",
          },
          {
            internalType: "bytes32",
            name: "parentMetaHash",
            type: "bytes32",
          },
          {
            internalType: "address",
            name: "sender",
            type: "address",
          },
        ],
        indexed: false,
        internalType: "struct TaikoData.BlockMetadata",
        name: "meta",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "address",
            name: "recipient",
            type: "address",
          },
          {
            internalType: "uint96",
            name: "amount",
            type: "uint96",
          },
          {
            internalType: "uint64",
            name: "id",
            type: "uint64",
          },
        ],
        indexed: false,
        internalType: "struct TaikoData.EthDeposit[]",
        name: "depositsProcessed",
        type: "tuple[]",
      },
    ],
    name: "BlockProposedV2",
    type: "event",
  },
];

function alertOrg(notificationClient, message) {
  notificationClient.send({
    channelAlias: "discord_bridging",
    subject: "🚨 TaikoL1: BlockProposed Alert",
    message,
  });

  notificationClient.send({
    channelAlias: "tg_taiko_guardians",
    subject: "🚨 TaikoL1: BlockProposed Alert",
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

  const allLogs = [];

  for (const eventName of eventNames) {
    const eventTopic = iface.getEventTopic(eventName);

    try {
      const logs = await provider.getLogs({
        address,
        fromBlock,
        toBlock,
        topics: [eventTopic],
      });

      allLogs.push(
        ...logs.map((log) =>
          iface.decodeEventLog(eventName, log.data, log.topics),
        ),
      );
    } catch (error) {
      console.error(`Error fetching logs for ${eventName}:`, error);
    }
  }

  return allLogs;
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
  const blocksInFiveMinutes = Math.floor((15 * 60) / blockTimeInSeconds);

  const fromBlock = currentBlockNumber - blocksInFiveMinutes;
  const toBlock = currentBlockNumber;

  const logs = await fetchLogsFromL1(
    ["BlockProposed", "BlockProposedV2"],
    fromBlock,
    toBlock,
    "0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a",
    ABI,
    taikoL1Provider,
  );

  console.log(`Logs found: ${logs.length}`);

  if (logs.length === 0) {
    alertOrg(
      notificationClient,
      `No BlockProposed event detected in the last 15 mins on TaikoL1!`,
    );
  }

  return true;
};
