export const gasLimitConfig = {
  GAS_RESERVE: 650_000, // based on Bridge.sol
  ethGasLimit: 100_000,
  erc20NotDeployedGasLimit: 750_000,
  erc20DeployedGasLimit: 500_000,
  erc721NotDeployedGasLimit: 2_400_000,
  erc721DeployedGasLimit: 1_100_000,
  erc1155NotDeployedGasLimit: 2_600_000,
  erc1155DeployedGasLimit: 1_100_000,
  // Fallback gas limits used when eth_estimateGas fails on the source tx.
  // Baselines are sized per token type from empirical Foundry gas reports (sendToken max):
  // ERC20 ~194k, ERC721 ~217k, ERC1155 ~215k. ERC721/1155 run ~2x ERC20 at the median
  // due to NFT transferFrom + metadata work; we keep a similar ~2.6x safety margin plus
  // headroom for multi-tokenId bundles.
  ethSendMessageFallbackGasLimit: 200_000,
  erc20SendTokenFallbackGasLimit: 500_000,
  erc721SendTokenFallbackGasLimit: 750_000,
  erc1155SendTokenFallbackGasLimit: 750_000,
  // Extra gas added when the bridged token isn't yet deployed on the destination chain.
  bridgeTxNotDeployedExtraGas: 750_000,
};

export const processingFeeComponent = {
  closingDelayOptionClick: 300,
  intervalComputeRecommendedFee: 20_000,
};

export const pendingTransaction = {
  waitTimeout: 90_000,
};

export const storageService = {
  bridgeTxPrefix: 'transactions',
  customTokenPrefix: 'custom-tokens',
};

export const bridgeTransactionPoller = {
  interval: 20_000,
};

export const claimConfig = {
  minimumEthToClaim: 0.0015, // 1M gas * 1.5 gwei (lowest gasPrice)
};

export const transactionConfig = {
  pageSizeDesktop: 6,
  pageSizeMobile: 5,
  blurTransitionTime: 300,
};

export const toastConfig = {
  duration: 5000,
};

export const apiService = {
  timeout: 10_000, // 10 seconds
};

export const ipfsConfig = {
  gatewayTimeout: 1_000,
  overallTimeout: 5_000,
};

export const moralisApiConfig = {
  limit: 10,
  format: 'decimal',
  excludeSpam: true,
  mediaItems: false,
};
