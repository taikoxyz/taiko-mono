import { GRIMSVOTN_CONFIG } from "./config";
import { AddEthereumChainParameter } from "../baseTypes";

export const GRIMSVOTN_ADD_ETHEREUM_CHAIN: AddEthereumChainParameter = {
  chainId: GRIMSVOTN_CONFIG.chainId.hex,
  chainName: GRIMSVOTN_CONFIG.names.mediumName,
  nativeCurrency: GRIMSVOTN_CONFIG.nativeCurrency,
  rpcUrls: [GRIMSVOTN_CONFIG.rpc.https],
  blockExplorerUrls: [GRIMSVOTN_CONFIG.blockExplorer.url],
  iconUrls: [],
};
