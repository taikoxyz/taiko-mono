export const recommendedProcessingFee = {
  ethGasLimit: BigInt(900_000),
  erc20NotDeployedGasLimit: BigInt(3_100_000),
  erc20DeployedGasLimit: BigInt(1_100_000),
  erc721NotDeployedGasLimit: BigInt(2_400_000),
  erc721DeployedGasLimit: BigInt(1_100_000),
  erc1155NotDeployedGasLimit: BigInt(2_600_000),
  erc1155DeployedGasLimit: BigInt(1_100_000),
};

export const processingFeeComponent = {
  closingDelayOptionClick: 300,
  intervalComputeRecommendedFee: 20_000,
};

export const bridgeService = {
  noOwnerGasLimit: BigInt(140_000),
  noERC20TokenDeployedGasLimit: BigInt(3_000_000),
  erc20GasLimitThreshold: BigInt(2_500_000),

  noERC721TokenDeployedGasLimit: BigInt(2_400_000),
  erc721GasLimitThreshold: BigInt(3_000_000),

  noERC1155TokenDeployedGasLimit: BigInt(2_600_000),
  erc1155GasLimitThreshold: BigInt(3_000_000),
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

export const statusComponent = {
  minimumEthToClaim: 0.0001,
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
