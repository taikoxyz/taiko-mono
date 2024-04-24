export const gasLimitConfig = {
  GAS_RESERVE: 650_000, // based on Bridge.sol
  ethGasLimit: BigInt(100_000),
  erc20NotDeployedGasLimit: BigInt(650_000),
  erc20DeployedGasLimit: BigInt(200_000),
  erc721NotDeployedGasLimit: BigInt(2_400_000),
  erc721DeployedGasLimit: BigInt(1_100_000),
  erc1155NotDeployedGasLimit: BigInt(2_600_000),
  erc1155DeployedGasLimit: BigInt(1_100_000),
};

export const processingFeeComponent = {
  closingDelayOptionClick: 300,
  intervalComputeRecommendedFee: 20_000,
};

export const pendingTransaction = {
  waitTimeout: 300_000,
};

export const storageService = {
  bridgeTxPrefix: 'transactions',
  customTokenPrefix: 'custom-tokens',
};

export const bridgeTransactionPoller = {
  interval: 20_000,
};

export const claimConfig = {
  minimumEthToClaim: 0.001,
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
  timeout: 5000,
};

export const ipfsConfig = {
  gatewayTimeout: 200,
  overallTimeout: 5000,
};
