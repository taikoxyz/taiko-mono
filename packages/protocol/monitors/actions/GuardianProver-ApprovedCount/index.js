const { ethers } = require("ethers");
const { Defender } = require("@openzeppelin/defender-sdk");

const ABI = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "operationId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "approvalBits",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "minGuardiansReached",
        type: "bool",
      },
    ],
    name: "Approved",
    type: "event",
  },
];

function alertOrg(notificationClient, message) {
  notificationClient.send({
    channelAlias: "discord_configs",
    subject: "⚠️ GuardianProver: Approved Count",
    message,
  });
}

async function getLatestBlockNumber(provider) {
  const currentBlock = await provider.getBlock("latest");
  return currentBlock.number;
}

async function calculateBlockTime(provider) {
  const latestBlock = await provider.getBlock("latest");
  const previousBlock = await provider.getBlock(latestBlock.number - 100);

  const timeDiff = latestBlock.timestamp - previousBlock.timestamp;
  const blockDiff = latestBlock.number - previousBlock.number;

  const blockTime = timeDiff / blockDiff;
  return blockTime;
}

async function calculateBlockRange(provider) {
  const currentBlockNumber = await getLatestBlockNumber(provider);
  const blockTimeInSeconds = await calculateBlockTime(provider);
  const blocksInOneHour = Math.floor((16 * 60) / blockTimeInSeconds);

  const fromBlock = currentBlockNumber - blocksInOneHour;
  const toBlock = currentBlockNumber;

  console.log(`Calculated block range: from ${fromBlock} to ${toBlock}`);

  return { fromBlock, toBlock };
}

async function fetchLogsFromL1(
  eventName,
  fromBlock,
  toBlock,
  address,
  abi,
  provider,
) {
  const iface = new ethers.utils.Interface(abi);
  const eventTopic = iface.getEventTopic(eventName);
  console.log(`eventTopic: ${eventTopic}`);
  try {
    const logs = await provider.getLogs({
      address,
      fromBlock,
      toBlock,
      topics: [eventTopic],
    });
    console.log(`Fetched logs: ${logs.length}`);
    return logs.map((log) => {
      const parsedLog = iface.parseLog(log);
      console.log(`Parsed log: ${JSON.stringify(parsedLog)}`);
      return parsedLog;
    });
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

exports.handler = async function (event, context) {
  const { notificationClient } = context;
  const { apiKey, apiSecret, taikoL1ApiKey, taikoL1ApiSecret } = event.secrets;

  const taikoL1Provider = createProvider(
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret,
  );

  const { fromBlock, toBlock } = await calculateBlockRange(taikoL1Provider);

  const logs = await fetchLogsFromL1(
    "Approved",
    fromBlock,
    toBlock,
    "0xE3D777143Ea25A6E031d1e921F396750885f43aC",
    ABI,
    taikoL1Provider,
  );

  if (logs.length > 0) {
    alertOrg(
      notificationClient,
      `@taiko|guardians Detected ${logs.length} Approved events in the last 15 mins on Guardian!`,
    );
  }

  return true;
};
