const { ethers } = require("ethers");
const { Defender } = require("@openzeppelin/defender-sdk");

const ABIs = {
  ERC1155Vault: [
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
  ],
  ERC721Vault: [
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
  ],
  ERC20Vault: [
    {
      anonymous: false,
      inputs: [
        {
          indexed: true,
          internalType: "uint256",
          name: "srcChainId",
          type: "uint256",
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
        {
          indexed: false,
          internalType: "uint8",
          name: "ctokenDecimal",
          type: "uint8",
        },
      ],
      name: "BridgedTokenDeployed",
      type: "event",
    },
  ],
};

function alertOrg(notificationClient, subject, message) {
  notificationClient.send({
    channelAlias: "discord_bridging",
    subject: subject,
    message: message,
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

async function monitorEvent(
  provider,
  eventName,
  fromBlock,
  toBlock,
  contractAddress,
  abi,
  subject,
  notificationClient,
) {
  const logs = await fetchLogs(
    eventName,
    fromBlock,
    toBlock,
    contractAddress,
    abi,
    provider,
  );
  const eventCount = logs.length;

  if (eventCount > 0) {
    const alertMessage = `ℹ️ Detected ${eventCount} ${subject} events on ${provider.network.name} in the last 24 hours!`;
    alertOrg(notificationClient, subject, alertMessage);
  }

  return;
}

exports.handler = async function (event, context) {
  const { notificationClient } = context;
  const {
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret,
    taikoL2ApiKey,
    taikoL2ApiSecret,
  } = event.secrets;

  const l1Provider = createProvider(
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret,
  );
  const l2Provider = createProvider(
    apiKey,
    apiSecret,
    taikoL2ApiKey,
    taikoL2ApiSecret,
  );

  const { fromBlock: l1FromBlock, toBlock: l1ToBlock } =
    await calculateBlockRange(l1Provider);
  const { fromBlock: l2FromBlock, toBlock: l2ToBlock } =
    await calculateBlockRange(l2Provider);

  await monitorEvent(
    l1Provider,
    "BridgedTokenDeployed",
    l1FromBlock,
    l1ToBlock,
    "0xaf145913EA4a56BE22E120ED9C24589659881702", // L1
    ABIs.ERC1155Vault,
    " ERC1155Vault.BridgedTokenDeployed",
    notificationClient,
  );

  await monitorEvent(
    l2Provider,
    "BridgedTokenDeployed",
    l2FromBlock,
    l2ToBlock,
    "0x1670000000000000000000000000000000000004", // L2
    ABIs.ERC1155Vault,
    " ERC1155Vault.BridgedTokenDeployed",
    notificationClient,
  );

  await monitorEvent(
    l1Provider,
    "BridgedTokenDeployed",
    l1FromBlock,
    l1ToBlock,
    "0x0b470dd3A0e1C41228856Fb319649E7c08f419Aa", // L1
    ABIs.ERC721Vault,
    " ERC721Vault.BridgedTokenDeployed",
    notificationClient,
  );

  await monitorEvent(
    l2Provider,
    "BridgedTokenDeployed",
    l2FromBlock,
    l2ToBlock,
    "0x1670000000000000000000000000000000000003", // L2
    ABIs.ERC721Vault,
    " ERC721Vault.BridgedTokenDeployed",
    notificationClient,
  );

  await monitorEvent(
    l1Provider,
    "BridgedTokenDeployed",
    l1FromBlock,
    l1ToBlock,
    "0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab", // L1
    ABIs.ERC20Vault,
    " ERC20Vault.BridgedTokenDeployed",
    notificationClient,
  );

  await monitorEvent(
    l2Provider,
    "BridgedTokenDeployed",
    l2FromBlock,
    l2ToBlock,
    "0x1670000000000000000000000000000000000002", // L2
    ABIs.ERC20Vault,
    " ERC20Vault.BridgedTokenDeployed",
    notificationClient,
  );

  return true;
};
