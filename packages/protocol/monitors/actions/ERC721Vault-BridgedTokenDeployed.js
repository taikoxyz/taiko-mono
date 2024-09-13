const { ethers } = require("ethers");
const { Defender } = require("@openzeppelin/defender-sdk");

const ABI = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint64",
        name: "chainId",
        type: "uint64",
      },
      {
        indexed: true,
        internalType: "address",
        name: "ctoken",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "btoken",
        type: "address",
      },
      {
        indexed: false,
        internalType: "string",
        name: "ctokenSymbol",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "ctokenName",
        type: "string",
      },
    ],
    name: "BridgedTokenDeployed",
    type: "event",
  },
];

function alertOrg(notificationClient, message) {
  notificationClient.send({
    channelAlias: "discord_bridging",
    subject: "ERC721Vault BridgedTokenDeployed Event Count",
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
  const blocksIn24Hours = Math.floor((24 * 60 * 60) / blockTimeInSeconds);

  const fromBlock = currentBlockNumber - blocksIn24Hours;
  const toBlock = currentBlockNumber;

  console.log(`Calculated block range: from ${fromBlock} to ${toBlock}`);

  return { fromBlock, toBlock };
}

async function fetchLogs(
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
    console.error("Error fetching logs:", error);
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
  const { apiKey, apiSecret, l1ApiKey, l1ApiSecret, l2ApiKey, l2ApiSecret } =
    event.secrets;

  const l1Provider = createProvider(apiKey, apiSecret, l1ApiKey, l1ApiSecret);
  const l2Provider = createProvider(apiKey, apiSecret, l2ApiKey, l2ApiSecret);

  const { fromBlock: l1FromBlock, toBlock: l1ToBlock } =
    await calculateBlockRange(l1Provider);
  const { fromBlock: l2FromBlock, toBlock: l2ToBlock } =
    await calculateBlockRange(l2Provider);

  const l1Logs = await fetchLogs(
    "BridgedTokenDeployed",
    l1FromBlock,
    l1ToBlock,
    "0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa",
    ABI,
    l1Provider,
  );

  const l2Logs = await fetchLogs(
    "BridgedTokenDeployed",
    l2FromBlock,
    l2ToBlock,
    "0x1670000000000000000000000000000000000003",
    ABI,
    l2Provider,
  );

  const l1EventCount = l1Logs.length;
  const l2EventCount = l2Logs.length;

  if (l1EventCount > 0 || l2EventCount > 0) {
    const alertMessage = `Detected ${l1EventCount} ERC721Vault BridgedTokenDeployed events on L1 and ${l2EventCount} events on L2 in the last 24 hours!`;
    alertOrg(notificationClient, alertMessage);
  }

  return true;
};
