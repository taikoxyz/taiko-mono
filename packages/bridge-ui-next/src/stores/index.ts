/**
 * Stores barrel ($stores alias).
 *
 * Mirrors the original bridge-ui stores/index.ts surface (account, metadataCache,
 * connectedSourceChain, pendingTransactions) and additionally re-exports the
 * theme/modal stores used by the app shell.
 *
 * React components import the hooks here. Non-React library callers must import
 * the VANILLA store objects (e.g. `modalStore`, `account`, `connectedSourceChain`)
 * or the shared queryClient directly, never the hooks.
 */

// Original $stores barrel surface (verbatim re-exports).
export { account } from "./account";
export { metadataCache } from "./metadata";
export { connectedSourceChain } from "./network";
export { pendingTransactions } from "./pendingTransactions";

// Theme / modal (app shell).
export {
  Theme,
  useThemeStore,
  applyTheme,
  resolveInitialTheme,
} from "./useThemeStore";
export { modalStore, useModalStore } from "./useModalStore";

// React hooks + additional store handles (so $stores callers can reach them).
export {
  useAccount,
  useSmartContractWallet,
  connectedSmartContractWallet,
} from "./account";
export { ethBalance, useEthBalanceStore } from "./balance";
export {
  switchingNetwork,
  useConnectedSourceChain,
  useSwitchingNetwork,
} from "./network";
export {
  usePendingTransactions,
  useAddPendingTransaction,
} from "./pendingTransactions";
export {
  bridgedTokens,
  setBridgedTokenInfoStore,
  getBridgedStatusFromStore,
  getBridgedTokenInfoStore,
} from "./bridgedToken";
export {
  tokenInfoStore,
  setTokenInfo,
  isCanonicalAddress,
  isBridgedAddress,
  type TokenInfo,
  type SetTokenInfoParams,
} from "./tokenInfo";
export {
  addMetadataToCache,
  getMetadataFromCache,
  isMetadataCached,
  type NFTCacheIdentifier,
} from "./metadata";
export { paginationInfo, relayerBlockInfoMap } from "./relayerApi";
