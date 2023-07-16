import { GRIMSVOTN_CONFIG, ELDFELL_CONFIG } from "./config";

// Interface from EIP-3085: https://eips.ethereum.org/EIPS/eip-3085
interface AddEthereumChainParameter {
  chainId: string; // A 0x-prefixed hexadecimal string
  blockExplorerUrls?: string[];
  chainName?: string;
  iconUrls?: string[];
  nativeCurrency: {
    name: string;
    symbol: string; // 2-6 characters long
    decimals: number;
  };
  rpcUrls: string[];
}

export const GRIMSVOTN_ADD_ETHEREUM_CHAIN: AddEthereumChainParameter = {
  chainId: GRIMSVOTN_CONFIG.chainId.hex,
  chainName: GRIMSVOTN_CONFIG.names.mediumName,
  nativeCurrency: GRIMSVOTN_CONFIG.nativeCurrency,
  rpcUrls: [GRIMSVOTN_CONFIG.rpc.https],
  blockExplorerUrls: [GRIMSVOTN_CONFIG.blockExplorer.url],
  iconUrls: [],
};

export const ELDFELL_ADD_ETHEREUM_CHAIN: AddEthereumChainParameter = {
  chainId: ELDFELL_CONFIG.chainId.hex,
  chainName: ELDFELL_CONFIG.names.mediumName,
  nativeCurrency: ELDFELL_CONFIG.nativeCurrency,
  rpcUrls: [ELDFELL_CONFIG.rpc.https],
  blockExplorerUrls: [ELDFELL_CONFIG.blockExplorer.url],
  iconUrls: [],
};
