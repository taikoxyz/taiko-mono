const {ethers} = require("ethers");
const {Defender} = require("@openzeppelin/defender-sdk");

const ABI = [
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
        indexed: false,
        internalType: "address",
        name: "btokenOld",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "btokenNew",
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
    name: "BridgedTokenChanged",
    type: "event",
  },
];

function alertOrg(notificationClient, message) {
  notificationClient.send({
    channelAlias: "discord_bridging",
    subject: "ER20Vault: BridgedTokenChanged Alert",
    message: message,
  });
}

async function getLatestBlockNumber(provider) {
  const currentBlock = await provider.getBlock("latest");
  return currentBlock.number;
}

async function fetchLogs(
  eventName,
  fromBlock,
  toBlock,
  address,
  abi,
  provider,
  networkName
) {
  const iface = new ethers.utils.Interface(abi);
  const eventTopic = iface.getEventTopic(eventName);

  try {
    const logs = await provider.getLogs({
      address,
      fromBlock,
      toBlock,
      topics: [eventTopic],
    });

    return logs.map((log) => {
      const parsedLog = iface.decodeEventLog(eventName, log.data, log.topics);
      return {...parsedLog, network: networkName};
    });
  } catch (error) {
    console.error(
      `Error fetching logs for ${eventName} on ${networkName}:`,
      error
    );
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

function calculateBlockRange(
  currentBlockNumber,
  blockTimeInSeconds,
  minutes = 5
) {
  const blocksInGivenMinutes = Math.floor((minutes * 60) / blockTimeInSeconds);
  const fromBlock = currentBlockNumber - blocksInGivenMinutes;
  const toBlock = currentBlockNumber;

  return {fromBlock, toBlock};
}

exports.handler = async function (event, context) {
  const {notificationClient} = context;
  const {
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret,
    taikoL2ApiKey,
    taikoL2ApiSecret,
  } = event.secrets;

  const taikoL1Provider = createProvider(
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret
  );
  const taikoL2Provider = createProvider(
    apiKey,
    apiSecret,
    taikoL2ApiKey,
    taikoL2ApiSecret
  );

  const currentBlockNumberL1 = await getLatestBlockNumber(taikoL1Provider);
  const currentBlockNumberL2 = await getLatestBlockNumber(taikoL2Provider);

  const blockTimeInSecondsL1 = await calculateBlockTime(taikoL1Provider);
  const blockTimeInSecondsL2 = await calculateBlockTime(taikoL2Provider);

  const {fromBlock: fromBlockL1, toBlock: toBlockL1} = calculateBlockRange(
    currentBlockNumberL1,
    blockTimeInSecondsL1
  );
  const {fromBlock: fromBlockL2, toBlock: toBlockL2} = calculateBlockRange(
    currentBlockNumberL2,
    blockTimeInSecondsL2
  );

  const logsL1 = await fetchLogs(
    "BridgedTokenChanged",
    fromBlockL1,
    toBlockL1,
    "0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab",
    ABI,
    taikoL1Provider,
    "L1"
  );
  const logsL2 = await fetchLogs(
    "BridgedTokenChanged",
    fromBlockL2,
    toBlockL2,
    "0x1670000000000000000000000000000000000002",
    ABI,
    taikoL2Provider,
    "L2"
  );

  const logs = [...logsL1, ...logsL2];

  if (logs.length > 0) {
    const logDetails = logs
      .map(
        (log) =>
          `Network: ${log.network}, Token: ${log.ctoken}, Old Token: ${log.btokenOld}, New Token: ${log.btokenNew}`
      )
      .join("\n");
    alertOrg(
      notificationClient,
      `BridgedTokenChanged event detected!\nDetails:\n${logDetails}`
    );
  }

  return true;
};
