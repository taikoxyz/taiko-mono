const {ethers} = require("ethers");
const {Defender} = require("@openzeppelin/defender-sdk");

const ERC20_ABI = [
  {
    constant: true,
    inputs: [{name: "_owner", type: "address"}],
    name: "balanceOf",
    outputs: [{name: "balance", type: "uint256"}],
    payable: false,
    stateMutability: "view",
    type: "function",
  },
];

async function getERC20Balance(provider, tokenAddress, vaultAddress) {
  const contract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
  return await contract.balanceOf(vaultAddress);
}

async function getNativeTokenBalance(provider, vaultAddress) {
  return await provider.getBalance(vaultAddress);
}

async function monitorTokenBalance(
  provider,
  tokenAddress,
  vaultAddress,
  previousBalanceKey,
  notificationClient,
  secrets,
  client,
  tokenName,
  networkName
) {
  console.log(`Monitoring ${tokenName} balance on ${networkName}`);
  const previousBalance = ethers.BigNumber.from(
    secrets[previousBalanceKey] || "0"
  );
  console.log(
    `Previous ${tokenName} Balance: ${ethers.utils.formatUnits(
      previousBalance,
      18
    )}`
  );

  let currentBalance;
  if (tokenName === "ETH") {
    currentBalance = await getNativeTokenBalance(provider, vaultAddress);
  } else {
    currentBalance = await getERC20Balance(
      provider,
      tokenAddress,
      vaultAddress
    );
  }
  console.log(
    `Current ${tokenName} Balance: ${ethers.utils.formatUnits(
      currentBalance,
      18
    )}`
  );

  if (!previousBalance.isZero()) {
    const dropPercentage = previousBalance
      .sub(currentBalance)
      .mul(100)
      .div(previousBalance)
      .toNumber();
    console.log(
      `Calculated drop percentage for ${tokenName}: ${dropPercentage}%`
    );

    if (dropPercentage >= 5) {
      const message = `Alert: ${tokenName} balance has dropped by ${dropPercentage}% on ${networkName}.\nPrevious Balance: ${ethers.utils.formatUnits(
        previousBalance,
        18
      )}\nCurrent Balance: ${ethers.utils.formatUnits(currentBalance, 18)}`;
      alertOrg(
        notificationClient,
        `${networkName}: ${tokenName} Balance Drop Alert`,
        message
      );
    } else {
      console.log(
        `No significant ${tokenName} balance drop detected on ${networkName}`
      );
    }
  } else {
    console.log(
      `No previous ${tokenName} balance to compare on ${networkName}`
    );
  }

  await storePreviousBalance(client, previousBalanceKey, currentBalance);
}

function alertOrg(notificationClient, subject, message) {
  notificationClient.send({
    channelAlias: "discord_bridging",
    subject: subject,
    message: message,
  });
}

async function storePreviousBalance(client, key, newBalance) {
  console.log(
    `Storing previous balance under key: ${key}, value: ${newBalance.toString()}`
  );
  const body = {
    deletes: [],
    secrets: {
      [key]: newBalance.toString(),
    },
  };
  await client.action.createSecrets(body);
}

function createProvider(apiKey, apiSecret, relayerApiKey, relayerApiSecret) {
  console.log(`Creating provider with API keys`);
  const client = new Defender({
    apiKey,
    apiSecret,
    relayerApiKey,
    relayerApiSecret,
  });

  return client.relaySigner.getProvider();
}

exports.handler = async function (event, context) {
  const {notificationClient} = context;
  const {apiKey, apiSecret, taikoL1ApiKey, taikoL1ApiSecret} = event.secrets;

  console.log(`Starting balance monitoring for L1`);

  const l1Provider = createProvider(
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret
  );

  const l1VaultAddress = "0x996282cA11E5DEb6B5D122CC3B9A1FcAAD4415Ab";

  const l1TokenAddresses = {
    ETH: null,
    TAIKO: ethers.utils.getAddress(
      "0x10dea67478c5F8C5E2D90e5E9B26dBe60c54d800"
    ),
    USDC: ethers.utils.getAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"),
    USDT: ethers.utils.getAddress("0xdAC17F958D2ee523a2206206994597C13D831ec7"),
  };

  const client = new Defender({
    apiKey,
    apiSecret,
    taikoL1ApiKey,
    taikoL1ApiSecret,
  });

  await monitorTokenBalance(
    l1Provider,
    l1TokenAddresses.ETH,
    l1VaultAddress,
    "previousBalance_L1_ETH",
    notificationClient,
    event.secrets,
    client,
    "ETH",
    "L1"
  );
  await monitorTokenBalance(
    l1Provider,
    l1TokenAddresses.TAIKO,
    l1VaultAddress,
    "previousBalance_L1_TAIKO",
    notificationClient,
    event.secrets,
    client,
    "TAIKO",
    "L1"
  );
  await monitorTokenBalance(
    l1Provider,
    l1TokenAddresses.USDC,
    l1VaultAddress,
    "previousBalance_L1_USDC",
    notificationClient,
    event.secrets,
    client,
    "USDC",
    "L1"
  );
  await monitorTokenBalance(
    l1Provider,
    l1TokenAddresses.USDT,
    l1VaultAddress,
    "previousBalance_L1_USDT",
    notificationClient,
    event.secrets,
    client,
    "USDT",
    "L1"
  );

  console.log(`Balance monitoring completed`);

  return true;
};
