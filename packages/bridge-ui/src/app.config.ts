/**
 * Destination gas added on top of the bridge's own minimum (`getMessageMinGasLimit`) for the
 * vault invocation, per token type and per whether the bridged token contract already exists
 * on the destination chain. This is the whole budget the relayer path forwards to the vault:
 * too little and the invocation fails, the message turns RETRIABLE and the owner has to claim
 * it themselves.
 *
 * Sized for EIP-8037 (Glamsterdam) state-creation pricing on every chain, before the fork as
 * well. Unspent gas is refunded to the destination owner when the message is processed, so
 * over-estimating only raises the fee quoted up front, while under-estimating after the fork
 * would strand every first-time token on the relayer path.
 *
 * Each value is the pre-8037 headroom plus the repricing of the fresh state the path creates,
 * with a 15% margin and rounded up to the next 100k. EIP-8037 prices state at 1,530 gas per
 * byte: a fresh storage slot (64 bytes) goes from 20,000 to 97,920, a new account (120 bytes)
 * from 32,000 to 183,600, and deployed code from 200 to 1,530 per byte - the 711-byte
 * ERC1967Proxy the vaults deploy alone adds ~946k. The fresh-slot counts per path are laid
 * out, and enforced against these numbers, in app.config.test.ts.
 */
export const gasLimitConfig = {
  erc20NotDeployedGasLimit: 3_700_000,
  erc20DeployedGasLimit: 700_000,
  erc721NotDeployedGasLimit: 5_300_000,
  erc721DeployedGasLimit: 1_300_000,
  erc1155NotDeployedGasLimit: 5_800_000,
  erc1155DeployedGasLimit: 1_200_000,
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
