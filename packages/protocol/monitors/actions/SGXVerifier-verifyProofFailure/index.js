const { ethers } = require("ethers");
const { Defender } = require("@openzeppelin/defender-sdk");

const verifyProofSignature = "verifyProof(address,bytes32,bytes32)";
const verifyProofSelector = ethers.utils
  .keccak256(ethers.utils.toUtf8Bytes(verifyProofSignature))
  .substring(0, 10);

function alertOrg(notificationClient, message) {
  notificationClient.send({
    channelAlias: "discord_blocks",
    subject: "⚠️ SGXVerifier: verifyProof Failure Alert",
    message,
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

async function calculateBlockRange(provider, hours = 24) {
  const currentBlockNumber = await getLatestBlockNumber(provider);
  const blockTimeInSeconds = await calculateBlockTime(provider);
  const blocksInTimeFrame = Math.floor((hours * 60 * 60) / blockTimeInSeconds);

  const fromBlock = currentBlockNumber - blocksInTimeFrame;
  const toBlock = currentBlockNumber;

  console.log(`Calculated block range: from ${fromBlock} to ${toBlock}`);

  return { fromBlock, toBlock };
}

async function monitorTransactions(
  provider,
  contractAddress,
  notificationClient,
  hours,
) {
  const { fromBlock, toBlock } = await calculateBlockRange(provider, hours);

  const logs = await provider.getLogs({
    fromBlock,
    toBlock,
    address: contractAddress,
  });

  for (const log of logs) {
    const tx = await provider.getTransaction(log.transactionHash);

    if (tx.data.startsWith(verifyProofSelector)) {
      const txReceipt = await provider.getTransactionReceipt(
        log.transactionHash,
      );

      if (txReceipt && txReceipt.status === 0) {
        const message = `
          A failed verifyProof transaction was detected.
          - Contract Address: ${log.address}
          - Transaction Hash: ${log.transactionHash}
          - Block Number: ${txReceipt.blockNumber}
        `;
        alertOrg(notificationClient, message);
      }
    }
  }
}

exports.handler = async function (event, context) {
  const { notificationClient } = context;
  const { apiKey, apiSecret, taikoL1ApiKey, taikoL1ApiSecret } = event.secrets;

  const contractAddress = "0xb0f3186FC1963f774f52ff455DC86aEdD0b31F81";

  const provider = createProvider(
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret,
  );

  await monitorTransactions(provider, contractAddress, notificationClient, 24);

  return true;
};
