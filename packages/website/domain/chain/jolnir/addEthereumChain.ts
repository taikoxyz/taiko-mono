import { JOLNIR_CONFIG } from "./config";
import { AddEthereumChainParameter } from "../baseTypes";

export const JOLNIR_ADD_ETHEREUM_CHAIN: AddEthereumChainParameter = {
  chainId: JOLNIR_CONFIG.chainId.hex,
  chainName: JOLNIR_CONFIG.names.mediumName,
  nativeCurrency: JOLNIR_CONFIG.nativeCurrency,
  rpcUrls: [JOLNIR_CONFIG.rpc.https],
  blockExplorerUrls: [JOLNIR_CONFIG.blockExplorer.url],
  iconUrls: [],
};
