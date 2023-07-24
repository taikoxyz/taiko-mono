import { AddEthereumChainParameter } from "../baseTypes";
import { ELDFELL_CONFIG } from "./config";

export const ELDFELL_ADD_ETHEREUM_CHAIN: AddEthereumChainParameter = {
  chainId: ELDFELL_CONFIG.chainId.hex,
  chainName: ELDFELL_CONFIG.names.mediumName,
  nativeCurrency: ELDFELL_CONFIG.nativeCurrency,
  rpcUrls: [ELDFELL_CONFIG.rpc.https],
  blockExplorerUrls: [ELDFELL_CONFIG.blockExplorer.url],
  iconUrls: [],
};
