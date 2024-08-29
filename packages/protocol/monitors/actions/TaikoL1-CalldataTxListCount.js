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
        indexed: false,
        internalType: "bytes",
        name: "txList",
        type: "bytes",
      },
    ],
    name: "CalldataTxList",
    type: "event",
  },
];

function alertOrg(notificationClient, message) {
  notificationClient.send({
    channelAlias: "discord_blocks",
    subject: "ℹ️ TaikoL1: CalldataTxList Count",
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
  const blocksIn24Hours = Math.floor((24 * 60 * 60) / blockTimeInSeconds); // 24 hours in seconds

  const fromBlock = currentBlockNumber - blocksIn24Hours;
  const toBlock = currentBlockNumber;

  console.log(`Calculated block range: from ${fromBlock} to ${toBlock}`);

  return { fromBlock, toBlock };
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
    ["CalldataTxList"],
    fromBlock,
    toBlock,
    "0x06a9Ab27c7e2255df1815E6CC0168d7755Feb19a",
    ABI,
    taikoL1Provider,
  );

  if (logs.length > 0) {
    alertOrg(
      notificationClient,
      `Detected ${logs.length} CalldataTxList events in the last 24 hours on TaikoL1!`,
    );
  }

  return true;
};
