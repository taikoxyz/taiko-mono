const { Defender } = require("@openzeppelin/defender-sdk");
const ethers = require("ethers");

const bridgeAbi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "msgHash",
        type: "bytes32",
      },
      {
        components: [
          {
            internalType: "uint64",
            name: "id",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "fee",
            type: "uint64",
          },
          {
            internalType: "uint32",
            name: "gasLimit",
            type: "uint32",
          },
          {
            internalType: "address",
            name: "from",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "srcChainId",
            type: "uint64",
          },
          {
            internalType: "address",
            name: "srcOwner",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "destChainId",
            type: "uint64",
          },
          {
            internalType: "address",
            name: "destOwner",
            type: "address",
          },
          {
            internalType: "address",
            name: "to",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "value",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "data",
            type: "bytes",
          },
        ],
        indexed: false,
        internalType: "struct IBridge.Message",
        name: "message",
        type: "tuple",
      },
      {
        components: [
          {
            internalType: "uint32",
            name: "gasUsedInFeeCalc",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "proofSize",
            type: "uint32",
          },
          {
            internalType: "uint32",
            name: "numCacheOps",
            type: "uint32",
          },
        ],
        indexed: false,
        internalType: "struct Bridge.ProcessingStats",
        name: "stats",
        type: "tuple",
      },
    ],
    name: "MessageProcessed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "bytes32",
        name: "msgHash",
        type: "bytes32",
      },
      {
        components: [
          {
            internalType: "uint64",
            name: "id",
            type: "uint64",
          },
          {
            internalType: "uint64",
            name: "fee",
            type: "uint64",
          },
          {
            internalType: "uint32",
            name: "gasLimit",
            type: "uint32",
          },
          {
            internalType: "address",
            name: "from",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "srcChainId",
            type: "uint64",
          },
          {
            internalType: "address",
            name: "srcOwner",
            type: "address",
          },
          {
            internalType: "uint64",
            name: "destChainId",
            type: "uint64",
          },
          {
            internalType: "address",
            name: "destOwner",
            type: "address",
          },
          {
            internalType: "address",
            name: "to",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "value",
            type: "uint256",
          },
          {
            internalType: "bytes",
            name: "data",
            type: "bytes",
          },
        ],
        indexed: false,
        internalType: "struct IBridge.Message",
        name: "message",
        type: "tuple",
      },
    ],
    name: "MessageSent",
    type: "event",
  },
];

async function getLogsByTopic(notificationClient, l1provider, l2provider) {
  const [
    processedMessagesL1,
    processedMessagesL2,
    sentMessagesL1,
    sentMessagesL2,
  ] = await Promise.all([
    fetchLogs(
      "MessageProcessed",
      1000,
      "0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC",
      bridgeAbi,
      l1provider,
    ),
    fetchLogs(
      "MessageProcessed",
      1000,
      "0x1670000000000000000000000000000000000001",
      bridgeAbi,
      l2provider,
    ),
    fetchLogs(
      "MessageSent",
      1000,
      "0xd60247c6848B7Ca29eDdF63AA924E53dB6Ddd8EC",
      bridgeAbi,
      l1provider,
    ),
    fetchLogs(
      "MessageSent",
      1000,
      "0x1670000000000000000000000000000000000001",
      bridgeAbi,
      l2provider,
    ),
  ]);

  const unmatchedL1 = findUnmatchedMessages(
    processedMessagesL1,
    sentMessagesL2,
  );
  const unmatchedL2 = findUnmatchedMessages(
    processedMessagesL2,
    sentMessagesL1,
  );

  if (unmatchedL1.length > 0 || unmatchedL2.length > 0) {
    const missingCount = unmatchedL1.length + unmatchedL2.length;
    alertOrg(notificationClient, missingCount);
  } else {
    console.log("All messages are matched.");
  }
}

async function fetchLogs(eventName, limit, address, abi, provider) {
  const currentBlock = await provider.getBlock("latest");
  const fromBlock = currentBlock.number - limit;

  const iface = new ethers.utils.Interface(abi);
  const eventTopic = iface.getEventTopic(eventName);

  try {
    const logs = await provider.getLogs({
      address,
      fromBlock,
      toBlock: currentBlock.number,
      topics: [eventTopic],
    });

    return logs.map(
      (log) => iface.decodeEventLog(eventName, log.data, log.topics).msgHash,
    );
  } catch (error) {
    console.error(`Error fetching ${eventName} logs:`, error);
    return [];
  }
}

function findUnmatchedMessages(processedMessages, sentMessages) {
  return processedMessages.filter((msgHash) => !sentMessages.includes(msgHash));
}

function alertOrg(notificationClient, missingCount) {
  const outputMessage = `Bridge Health Alert! \nThere are ${missingCount} missing MessageSent events for the processed messages on the other chain.`;

  notificationClient.send({
    channelAlias: "discord_bridging",
    subject: "🚨 Bridge: MessageProcessed",
    message: outputMessage,
  });
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

  await getLogsByTopic(notificationClient, l1Provider, l2Provider);

  return true;
};
