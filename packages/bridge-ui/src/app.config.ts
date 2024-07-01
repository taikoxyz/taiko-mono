export const gasLimitConfig = {
  GAS_RESERVE: 650_000, // based on Bridge.sol
  ethGasLimit: 100_000,
  erc20NotDeployedGasLimit: 750_000,
  erc20DeployedGasLimit: 500_000,
  erc721NotDeployedGasLimit: 2_400_000,
  erc721DeployedGasLimit: 1_100_000,
  erc1155NotDeployedGasLimit: 2_600_000,
  erc1155DeployedGasLimit: 1_100_000,
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
