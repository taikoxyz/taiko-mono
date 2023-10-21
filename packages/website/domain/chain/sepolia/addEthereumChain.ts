import { AddEthereumChainParameter } from "../baseTypes";
import { SEPOLIA_CONFIG } from "./config";

export const SEPOLIA_ADD_ETHEREUM_CHAIN: AddEthereumChainParameter = {
  chainId: SEPOLIA_CONFIG.chainId.hex,
  chainName: SEPOLIA_CONFIG.names.mediumName,
  nativeCurrency: SEPOLIA_CONFIG.nativeCurrency,
  rpcUrls: [SEPOLIA_CONFIG.rpc.https],
  blockExplorerUrls: [SEPOLIA_CONFIG.blockExplorer.url],
  iconUrls: [],
};

